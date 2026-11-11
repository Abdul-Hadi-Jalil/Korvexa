# 4. Getting Started

This chapter gets both halves of Korvexa running on your machine and shows the
first end-to-end flow (register → create a project → add a task). Every command
here is copy-pasteable.

## Prerequisites

| Tool | Version | Needed for |
|------|---------|-----------|
| Python | 3.11+ (3.12/3.13 fine) | Backend |
| Flutter | 3.x (Dart 3) | Frontend |
| Docker | recent | Optional: local Postgres / running the API in a container |
| Git | any | Cloning |

No database server is required to start: the default configuration uses a local
**SQLite** file, so the backend runs with zero external services.

## 1. Choose a database

You pick a database by setting one environment variable, `DATABASE_URL`. No code
changes are needed to switch. See the [Configuration Reference](15-configuration-reference.md)
for the full list of variables.

| Option | `DATABASE_URL` | Notes |
|--------|----------------|-------|
| **SQLite** (default) | `sqlite:///./korvexa.db` | Zero setup; great for dev |
| **Local Postgres** | `postgresql+psycopg2://korvexa:korvexa@localhost:5432/korvexa` | `docker compose up -d db` |
| **Supabase** | `postgresql+psycopg2://postgres:[PW]@[HOST]:5432/postgres` | Use the URI from Supabase, swap the scheme prefix |

For your first run, do nothing — the SQLite default in
[`backend/.env.example`](../backend/.env.example) is used.

## 2. Run the backend

```bash
cd backend
python -m venv .venv

# Activate the virtualenv:
# Windows (PowerShell):
.venv\Scripts\Activate.ps1
# macOS / Linux:
source .venv/bin/activate

pip install -r requirements-dev.txt   # runtime + test deps
cp .env.example .env                   # optional; defaults work as-is

alembic upgrade head                   # build the schema (source of truth)
uvicorn app.main:app --reload          # serve on http://127.0.0.1:8000
```

Verify it's up:

```bash
curl http://127.0.0.1:8000/health
# {"status":"ok"}
```

Open the interactive API docs at **http://127.0.0.1:8000/docs** — every endpoint
is browsable and callable there.

> **Why `alembic upgrade head` and not automatic table creation?** Migrations
> are the single source of truth for the schema in Korvexa. The production path
> never calls `create_all`. See [Chapter 6](06-data-model-and-migrations.md).

### Windows note

On Windows, create the virtualenv with the standard python.org interpreter (the
one that produces a `.venv\Scripts\` layout). Some MSYS2/MinGW Python builds
report a non-standard platform tag and fail to install binary wheels like
`pydantic-core`.

## 3. Run the frontend

In a second terminal:

```bash
cd frontend
flutter pub get
flutter run -d chrome    # or: -d windows, -d macos, an emulator, etc.
```

The app opens to a **login screen**. Because there are no users yet, click
**"Don't have an account? Register"**, create one, and you're in.

### Pointing the app at the backend

The frontend picks an API base URL per platform (see
[`frontend/lib/config.dart`](../frontend/lib/config.dart)):

- Web / desktop → `http://127.0.0.1:8000`
- Android emulator → `http://10.0.2.2:8000` (the emulator's alias for host
  localhost)

Override it at build/run time:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8000
```

## 4. First end-to-end flow

Once logged in:

1. On **Projects**, tap the **+** to create a project (a key like `ACME` is
   derived from the name automatically).
2. Open the project to see its **board**. Use a column's **+** to add a task; it
   gets a key like `ACME-1`.
3. Drag the card between columns; drop it onto another card to reorder.
4. Tap a card → **Details** to edit fields, add **comments**, assign it, and add
   **labels**; the **Activity** tab shows the history.
5. The **My Tasks** tab shows open tasks (toggle "Assigned to me only").
6. The top bar has the **workspace switcher**, a **notification bell**, and an
   account menu (**Members**, **Log out**).

## 5. Run the tests

```bash
cd backend
pytest                       # ~166 tests
pytest --cov=app --cov-report=term-missing   # with coverage (~92%)
```

```bash
cd frontend
flutter analyze              # static analysis (should be clean)
flutter test                 # widget smoke test
```

Testing is covered in depth in [Chapter 16](16-testing.md).

## 6. Optional: run everything in Docker

```bash
# From the repo root — builds the API image and starts api + Postgres.
SECRET_KEY=$(openssl rand -hex 32) docker compose up --build
# API on http://localhost:8000 ; migrations run automatically on start.
```

Deployment details, including cloud targets, are in [Chapter 17](17-deployment.md).

## Common first-run issues

| Symptom | Fix |
|---------|-----|
| `pydantic-core` fails to build on Windows | Use the standard python.org Python, not MSYS2/MinGW |
| Flutter app shows a network error | Backend not running, or wrong `API_BASE_URL` for your platform |
| `401` on every API call | You're not logged in / the token expired; the app should route you to login |
| `alembic: command not found` | Activate the virtualenv first |

More in [Chapter 19 — Troubleshooting & FAQ](19-troubleshooting-faq.md).

---

Previous: [Chapter 3 — Architecture](03-architecture.md) ·
Next: [Chapter 5 — Backend Foundation](05-backend-foundation.md)
