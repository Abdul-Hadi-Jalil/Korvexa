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
- [x] **Phase 1** — Core MVP (single user)
- [ ] Phase 2 — Depth & polish
- [ ] Phase 3 — Teams & auth
- [ ] Phase 4 — Hardening & ship

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

## Architecture: the "team later" seam

Every table that holds user data is already scoped by `workspace_id`, and a
`memberships` table already models "which users belong to which workspace
with which role" — even though Phase 1 only ever creates one user, one
workspace, and one membership row (seeded on first run). All Phase 1–2 routes
resolve the current workspace through a single dependency,
`get_current_workspace`. Phase 3 swaps that dependency's implementation to
resolve the workspace from a real JWT + membership check instead of "the only
workspace that exists" — no route code, no schema changes. That single seam
is what lets the same data model support one user on day one and a small team
later.

## Repo layout

```
backend/
  app/
    core/        # settings
    models/      # SQLModel table models
    schemas/     # request/response DTOs
    routers/     # FastAPI routers
  alembic/       # migrations (source of truth for the schema)
  tests/         # pytest suite
frontend/
  lib/
    config.dart    # API base URL per platform
    screens/       # UI screens
    widgets/       # shared UI pieces (e.g. task card)
    providers/     # ChangeNotifier state (provider package)
    models/        # Dart data models
    services/      # API client + per-resource services
docker-compose.yml   # local Postgres
```

## Contributing / working agreement

See the commit history — one commit per phase, e.g. `feat(phase-1): core MVP`.
Every backend endpoint has automated tests covering the happy path and
failure cases (validation, not-found, ownership). Migrations, not
`create_all`, are the source of truth for the schema in the production path.
