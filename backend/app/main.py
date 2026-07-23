from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from app.core.config import get_settings
from app.core.rate_limit import limiter
from app.routers import (
    activity,
    auth,
    comments,
    health,
    labels,
    me,
    notifications,
    projects,
    tasks,
    workspaces,
)

settings = get_settings()

app = FastAPI(title="Korvexa API", version="0.1.0")

# Rate limiting (auth endpoints; see app/core/rate_limit.py).
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
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
app.include_router(me.router)
