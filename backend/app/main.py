from __future__ import annotations

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi.errors import RateLimitExceeded

from app.core.config import get_settings
from app.core.errors import register_exception_handlers
from app.core.logging import (
    RequestContextMiddleware,
    configure_logging,
    request_id_ctx,
)
from app.core.rate_limit import limiter
from app.routers import (
    activity,
    auth,
    comments,
    dashboard,
    health,
    labels,
    me,
    notifications,
    projects,
    search,
    tasks,
    workspaces,
)

settings = get_settings()
configure_logging()

DESCRIPTION = """
Korvexa — a self-hostable, Jira-style task manager.

**Auth:** obtain tokens via `POST /auth/register` or `POST /auth/login`, then
send `Authorization: Bearer <access_token>`. Select the active workspace with
the `X-Workspace-Id` header (defaults to your first workspace). Refresh with
`POST /auth/refresh`.

**Errors** share one envelope: `{"detail": "...", "request_id": "..."}` (plus
`errors` for validation failures). The `request_id` also comes back in the
`X-Request-ID` response header and appears in server logs.
"""

app = FastAPI(
    title="Korvexa API",
    version="1.0.0",
    description=DESCRIPTION,
    openapi_tags=[
        {"name": "auth", "description": "Registration, login, token refresh, current user."},
        {"name": "workspaces", "description": "Workspaces, members, invites, roles."},
        {"name": "projects", "description": "Projects (owner-only delete)."},
        {"name": "tasks", "description": "Tasks, board, reorder, labels, assignees."},
        {"name": "labels", "description": "Workspace-scoped labels."},
        {"name": "comments", "description": "Task comments (@mentions notify members)."},
        {"name": "activity", "description": "Per-task activity log."},
        {"name": "notifications", "description": "In-app notifications."},
        {"name": "dashboard", "description": "Workspace aggregate stats."},
        {"name": "search", "description": "Workspace-wide task search."},
        {"name": "me", "description": "Cross-project views (upcoming, calendar)."},
        {"name": "health", "description": "Liveness probe."},
    ],
)

# Observability: request id + structured access logging, then a consistent
# error envelope for every failure mode.
app.add_middleware(RequestContextMiddleware)
register_exception_handlers(app)

# Rate limiting for auth endpoints.
app.state.limiter = limiter


@app.exception_handler(RateLimitExceeded)
async def _rate_limit_handler(request: Request, exc: RateLimitExceeded) -> JSONResponse:
    return JSONResponse(
        status_code=429,
        content={
            "detail": f"Rate limit exceeded: {exc.detail}",
            "request_id": request_id_ctx.get(),
        },
    )


app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["X-Request-ID"],
)

app.include_router(health.router)
app.include_router(auth.router)
app.include_router(workspaces.router)
app.include_router(projects.router)
app.include_router(tasks.router)
app.include_router(labels.router)
app.include_router(comments.router)
app.include_router(activity.router)
app.include_router(notifications.router)
app.include_router(dashboard.router)
app.include_router(search.router)
app.include_router(me.router)
