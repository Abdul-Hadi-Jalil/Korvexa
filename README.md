# Korvexa

A simple, self-hostable Jira-style task manager. Built to work well for a
single user today, with a "team later" seam (see below) that Phase 3 turns
into real multi-user workspaces.

- **Backend:** Python 3.11+, FastAPI, SQLModel (SQLAlchemy + Pydantic), Alembic, Uvicorn.
- **Database:** PostgreSQL by default; runs unchanged against Supabase or local SQLite by swapping one `DATABASE_URL` env var.
- **Frontend:** Flutter (Dart 3), `provider` for state, `http` for networking, `intl` for dates.
- **Repo layout:** [backend/](backend/) (API) and [frontend/](frontend/) (Flutter app) at the root.

## Project status

Building phase by phase. Each phase's acceptance tests must be green before
the next begins.

- [x] Phase 0 — Scaffolding
- [x] Phase 1 — Core MVP (single user)
- [x] Phase 2 — Depth & polish
- [x] Phase 3 — Teams & auth
- [x] **Phase 4** — Hardening & ship

### Phase 4 features

- **Consistent error envelope** for every failure — `{"detail": "...",
  "request_id": "..."}` (plus `errors` for validation), so clients and logs
  agree.
- **Structured logging with request IDs**: each request gets an id (honoring
  an inbound `X-Request-ID`), returned in the `X-Request-ID` response header
  and stamped on every log line for that request.
- **Rate limiting** on `POST /auth/register` and `POST /auth/login`
  (configurable via `RATE_LIMIT_AUTH`, default `10/minute`).
- **Dockerfile + `docker-compose` (api + db)** with migrations applied on
  container start; an optional demo seed (`python -m app.seed`, or
  `SEED_DEMO=true`); polished OpenAPI docs at `/docs`.

### Phase 3 features

- **Real auth:** register / login / `/auth/me`, JWT access + refresh tokens,
  bcrypt password hashing. `get_current_workspace` now resolves the acting
  user from the bearer token and the active workspace from the
  `X-Workspace-Id` header, enforcing membership on every route.
- **Multiple workspaces per user** with a switcher; **invite by email** →
  membership with a role (a passwordless placeholder account is created for
  unknown emails and claimed on registration).
- **Role enforcement:** only an `owner` can delete a project or add/remove/
  re-role members.
- **Assignees:** assign tasks to workspace members (validated against
  membership); "My Tasks" can filter to `assignee = me`; the assignee shows
  on cards.
- **In-app notifications** on assignment and on `@mention` in a comment, with
  unread counts and mark-read; email delivery is a logged stub.

### Phase 2 features

- **Comments** on tasks (create/edit/delete your own; author + timestamps), paginated.
- **Labels** (workspace-scoped): create, assign several to a task, filter the board by label.
- **Search & filter** tasks by title/description text, status, priority, label, and due window.
- **Reorder within a column** via fractional `position` (`POST /tasks/{id}/reorder` takes an
  explicit `position` or `before_id`/`after_id`); moving one card writes only that card's row.
- **Activity log** per task (created, status change, field edits), `GET /tasks/{id}/activity`.
- **Archive/unarchive** projects; archived hidden from the default list.
- **Pagination** (limit/offset envelope `{items,total,limit,offset}`) on task and comment lists.

## Quickstart

### 1. Database

Pick one — no code changes are needed to switch, only `DATABASE_URL`:

**Option A: local SQLite (fastest, zero setup)** — this is the default in
`.env.example`, nothing to run.

**Option B: local Postgres via Docker**

```bash
docker compose up -d
# DATABASE_URL=postgresql+psycopg2://korvexa:korvexa@localhost:5432/korvexa
```

**Option C: Supabase** — copy the Postgres connection string from your
Supabase project (Database > Connection string > URI) into `DATABASE_URL`,
changing the driver prefix to `postgresql+psycopg2://`.

### 2. Backend

```bash
cd backend
python -m venv .venv
# Windows:
.venv\Scripts\activate
# macOS/Linux:
source .venv/bin/activate

pip install -r requirements-dev.txt
cp .env.example .env        # edit DATABASE_URL if not using SQLite

alembic upgrade head        # builds the schema — this is the source of truth
uvicorn app.main:app --reload
```

The API is now serving at `http://127.0.0.1:8000`. Check `GET /health`, and
browse interactive docs at `/docs`.

Run the test suite (each test gets its own throwaway SQLite DB built by
`alembic upgrade head`, so a broken migration fails tests loudly):

```bash
pytest
```

### 3. Frontend

```bash
cd frontend
flutter pub get
flutter run -d chrome                     # web/desktop default API base URL
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000   # Android emulator
```

`lib/config.dart` picks a sensible default API base URL per platform,
overridable with `--dart-define=API_BASE_URL=...`.

### Manual Flutter smoke test (Phase 1)

Automated widget tests use a mocked HTTP client (see `test/widget_test.dart`),
so the following talks to a *real* running backend and is worth doing by hand
after any board/task change:

1. Start the backend (`uvicorn app.main:app --reload`) and `flutter run -d chrome`.
2. **Projects tab** loads empty, then "Create your first project" makes one
   (key auto-derived from the name); it appears in the list with `0/0 open`.
3. Tap the project to open its **board** (To Do / In Progress / Done columns).
4. Use each column's `+` to add a task; it lands in that column with a
   `KEY-1`-style label.
5. Drag a card to another column — it moves and the counts update; reopening
   the board (pull to refresh) shows the same state, proving the move
   persisted server-side, not just in local UI state.
6. Tap a card to open **task edit**: change title/status/priority/due date,
   save, and confirm the board reflects it. Delete a task from this screen
   and confirm it disappears from the board.
7. Switch to the **My Tasks** tab; toggle Today / This Week / All Open and
   confirm the due-date filtering matches what you'd expect, overdue dates
   render in red, and each row shows its project.
8. Kill and restart the backend process — the same workspace/project/task
   data is still there (proves persistence, not in-memory state).

### Manual Flutter smoke test (Phase 2)

9. On the board, use the **search field** and **priority / due / label filter**
   chips; confirm the columns narrow accordingly and "clear filters" resets them.
10. Create a **label** via the `+ Label` chip, then open a card → **Details**
    tab → **Edit** labels; the chip shows on the card and filters the board.
11. **Reorder within a column**: drag a card onto another card in the same
    column — an insertion line appears and the order persists after refresh.
    Drag across columns onto a card to move + position in one gesture.
12. On a card's **Details** tab, add/edit/delete **comments**; switch to the
    **Activity** tab and confirm entries appear for creation, status changes,
    and field edits (newest first).
13. From the projects list, **archive** a project (long-press/menu) and confirm
    it disappears from the default list but its data is intact when unarchived.

## Architecture: the "team later" seam

Every table that holds user data is scoped by `workspace_id`, and a
`memberships` table models "which users belong to which workspace with which
role". Phase 1–2 ran single-user: one seeded user/workspace/membership, and
every route resolved the active workspace through one dependency,
`get_current_workspace` ("the only workspace that exists").

**Phase 3 realized the seam by rewriting only that dependency** (see
[backend/app/deps.py](backend/app/deps.py)): it now resolves the acting user
from the JWT and the active workspace from the `X-Workspace-Id` header,
enforcing membership. Because the dependency still returns a `Workspace`, none
of the Phase 1–2 route code changed — the same handlers that served one user
now serve a team. The test suite proves the isolation both ways: the Phase
1–2 tests still pass (via an authenticated test client), and new two-user
tests prove user A cannot read, write, or even confirm the existence of user
B's workspace.

## Architecture overview

```
Flutter app  ──HTTP(JSON)──▶  FastAPI
  SessionController (tokens,          │  RequestContextMiddleware (request id + access log)
  active workspace, secure storage)  │  exception handlers → {detail, request_id}
  ApiClient injects:                 │  routers → deps.get_current_user / get_current_workspace
    Authorization: Bearer <access>   │            (JWT + X-Workspace-Id → membership check)
    X-Workspace-Id: <id>             │  SQLModel ORM
  auto-refreshes on 401              ▼
                              Alembic-migrated DB
                        SQLite | Postgres | Supabase  (one DATABASE_URL)
```

- **One workspace seam.** Every data row is scoped by `workspace_id`; every
  route resolves the active workspace through `get_current_workspace`. Swapping
  that one dependency is what took the app from single-user (Phase 1) to
  multi-tenant teams (Phase 3) without touching handler code.
- **Migrations are the source of truth.** The schema is built by
  `alembic upgrade head` in dev, tests (each test builds its own DB from the
  migrations), and on container start — never `create_all` in the production
  path.
- **Database-agnostic.** Synchronous SQLAlchemy + a SQLite FK pragma and
  Alembic batch mode keep one codebase valid on SQLite, Postgres, and Supabase.
- **Small, composable modules.** Routers stay thin; cross-cutting logic
  (serialization, activity, notifications, task-labels) lives in `app/services`.

### Repo layout

```
backend/
  app/
    core/        # settings, security (JWT/bcrypt), logging, errors, rate limit
    models/      # SQLModel table models
    schemas/     # request/response DTOs
    routers/     # FastAPI routers (auth, workspaces, projects, tasks, ...)
    services/    # cross-cutting logic (notifications, serialization, ...)
    utils/       # key generation, fractional-rank positions
    deps.py      # the auth + workspace "team later" seam
    seed.py      # demo-data seeder (python -m app.seed)
  alembic/       # migrations (source of truth for the schema)
  tests/         # pytest suite (162 tests)
  Dockerfile
  entrypoint.sh  # runs `alembic upgrade head`, then uvicorn
frontend/
  lib/
    config.dart    # API base URL per platform
    screens/       # UI screens (auth gate, board, task detail, members, ...)
    widgets/       # shared UI pieces (task card, comments, activity, labels)
    providers/     # ChangeNotifier state (provider package)
    models/        # Dart data models
    services/      # ApiClient, SessionController, per-resource services
docker-compose.yml   # api + db
```

## Testing & coverage

```bash
cd backend
pytest                                  # 162 tests
pytest --cov=app --cov-report=term-missing --cov-report=html
```

Coverage is **~92%** of `app/` (HTML report in `backend/htmlcov/`). Each test
builds its own throwaway SQLite database from `alembic upgrade head`, so a
broken migration fails the suite rather than being silently papered over. The
bcrypt work factor is lowered in tests via `BCRYPT_ROUNDS` (set in
`tests/conftest.py`) so hashing doesn't dominate the run.

Frontend: `cd frontend && flutter analyze && flutter test`.

## Deployment

Migrations run automatically on container start (`entrypoint.sh` →
`alembic upgrade head`), so every deploy converges the schema before serving.

### Docker (self-host)

```bash
# Builds the API image and starts api + Postgres; API on :8000.
SECRET_KEY=$(openssl rand -hex 32) docker compose up --build
# Optionally seed demo data on first boot:
SEED_DEMO=true SECRET_KEY=... docker compose up --build
```

For local dev where you run `uvicorn` yourself, start just the database:
`docker compose up -d db`.

### Fly.io / Railway / Render

All three build the backend from `backend/Dockerfile`; set these env vars:

| Var | Value |
| --- | --- |
| `DATABASE_URL` | `postgresql+psycopg2://…` (managed Postgres or Supabase) |
| `SECRET_KEY` | a long random string (`openssl rand -hex 32`) |
| `CORS_ORIGINS` | JSON array of your web app origin(s), e.g. `["https://app.example.com"]` |
| `RATE_LIMIT_AUTH` | optional, default `10/minute` |

- **Fly.io:** `fly launch --dockerfile backend/Dockerfile`, attach Postgres
  with `fly postgres create` + `fly postgres attach`, then `fly deploy`. The
  entrypoint runs migrations on each release.
- **Railway:** point a service at `backend/`, add a Postgres plugin (it injects
  `DATABASE_URL` — prefix it with `postgresql+psycopg2://`), set `SECRET_KEY`.
- **Render:** a Web Service from `backend/Dockerfile` + a Render Postgres
  instance; set the env vars above.

### Supabase (managed Postgres)

Copy the connection string from **Database → Connection string → URI**, change
the scheme to `postgresql+psycopg2://`, and set it as `DATABASE_URL`. No code
changes — run `alembic upgrade head` (or just deploy; the entrypoint does it).

## Flutter build notes

The app reads its API base URL from `--dart-define=API_BASE_URL=…` (defaults:
`127.0.0.1:8000` on web/desktop, `10.0.2.2:8000` on the Android emulator).

```bash
cd frontend

# Web
flutter build web --release --dart-define=API_BASE_URL=https://api.example.com
# Output in build/web/ — serve as static files (Netlify, Nginx, Cloudflare Pages).
# Note: flutter_secure_storage_web uses dart:js_util, so the default JS build
# is used (not --wasm).

# Windows desktop (native target)
flutter build windows --release --dart-define=API_BASE_URL=https://api.example.com

# Android
flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com
```

## Demo credentials

After `python -m app.seed` (or `SEED_DEMO=true`):

- Owner: `demo@korvexa.app` / `demo-password-123`
- Member: `teammate@korvexa.app` / `demo-password-123`

## Contributing / working agreement

One commit per phase (see `git log`: `feat(phase-0)` … `feat(phase-4)`). Every
backend endpoint has automated tests covering the happy path and failure cases
(validation, not-found, ownership/permission). Migrations, not `create_all`,
are the source of truth for the schema in the production path. Multi-tenant
isolation and role permissions are proven by tests.
