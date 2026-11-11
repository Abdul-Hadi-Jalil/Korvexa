# 21. Appendix

Reference material: the complete file tree with a one-line description of every
file, the dependency list, a command cheat sheet, and the version history.

## Full file tree

### Repository root

```
korvexa/
├── README.md              # Top-level quickstart + architecture summary
├── docker-compose.yml     # api + Postgres services for self-hosting
├── .gitignore             # Ignores venv, build output, .env, coverage, etc.
├── backend/               # FastAPI application (see below)
├── frontend/              # Flutter application (see below)
└── book/                  # This documentation
```

### Backend — `backend/`

```
backend/
├── requirements.txt          # Runtime dependencies
├── requirements-dev.txt      # Test/dev deps (includes requirements.txt)
├── pytest.ini                # pytest config (test paths, pythonpath)
├── .coveragerc               # coverage.py config (source=app)
├── .env.example              # Template for the .env config file
├── alembic.ini               # Alembic configuration
├── Dockerfile                # Backend container image
├── entrypoint.sh             # Container start: migrate → (seed) → uvicorn
│
├── alembic/
│   ├── env.py                # Alembic runtime: metadata + DB URL selection
│   ├── script.py.mako        # Template for new migration files
│   └── versions/
│       ├── 0001_initial_schema.py               # users, workspaces, memberships, projects, tasks
│       ├── 0002_phase2_comments_labels_activity.py  # comments, labels, task_labels, activity_log
│       └── 0003_phase3_notifications.py         # notifications table
│
├── app/
│   ├── __init__.py           # Package marker
│   ├── main.py               # App assembly: middleware, error handlers, routers
│   ├── db.py                 # SQLAlchemy engine + get_session; SQLite FK pragma
│   ├── deps.py               # Auth/tenancy dependencies — "the seam"
│   ├── seed.py               # Demo-data seeder + `python -m app.seed` CLI
│   │
│   ├── core/
│   │   ├── __init__.py
│   │   ├── config.py         # Settings (pydantic-settings)
│   │   ├── security.py       # bcrypt hashing + JWT create/decode
│   │   ├── logging.py        # Request-id middleware + structured logging
│   │   ├── errors.py         # Exception handlers → consistent error envelope
│   │   └── rate_limit.py     # slowapi limiter instance
│   │
│   ├── models/               # SQLModel tables
│   │   ├── __init__.py       # Imports all models (populates metadata)
│   │   ├── user.py           # User (email, name, nullable password_hash)
│   │   ├── workspace.py      # Workspace (name, owner_id)
│   │   ├── membership.py     # Membership (workspace, user, role) + MembershipRole
│   │   ├── project.py        # Project (workspace, key, archived, task_counter)
│   │   ├── task.py           # Task + TaskStatus/TaskPriority enums
│   │   ├── comment.py        # Comment (task, author, body)
│   │   ├── label.py          # Label + TaskLabel join table
│   │   ├── activity.py       # ActivityLog (append-only per-task history)
│   │   └── notification.py   # Notification (assigned | mention)
│   │
│   ├── schemas/              # Request/response DTOs (not tables)
│   │   ├── __init__.py
│   │   ├── auth.py           # Register/Login/Refresh, TokenPair, UserRead
│   │   ├── workspace.py      # Workspace/Member/Invite/Role + NotificationRead
│   │   ├── project.py        # ProjectCreate/Update/Read (+ counts)
│   │   ├── task.py           # TaskCreate/Update/Reorder/Read/WithProjectRead
│   │   ├── label.py          # LabelCreate/Update/Read, TaskLabelsSet
│   │   ├── comment.py        # CommentCreate/Update/Read
│   │   ├── activity.py       # ActivityRead
│   │   └── pagination.py     # Generic Page[T] envelope
│   │
│   ├── routers/              # FastAPI routers (the API surface)
│   │   ├── __init__.py
│   │   ├── health.py         # GET /health
│   │   ├── auth.py           # /auth/register|login|refresh|me (rate-limited)
│   │   ├── workspaces.py     # /workspaces, members, invite, roles
│   │   ├── projects.py       # /projects CRUD, archive, owner-only delete
│   │   ├── tasks.py          # tasks CRUD, board, reorder, labels (largest router)
│   │   ├── labels.py         # /labels CRUD
│   │   ├── comments.py       # task comments (author-only edit/delete)
│   │   ├── activity.py       # GET /tasks/{id}/activity
│   │   ├── notifications.py  # list/count/read/read_all
│   │   └── me.py             # GET /me/upcoming (cross-project)
│   │
│   ├── services/             # Cross-cutting logic shared by routers
│   │   ├── __init__.py
│   │   ├── serialization.py  # ORM→schema, batched label loading (no N+1)
│   │   ├── activity.py       # record_activity() helper
│   │   ├── notifications.py  # notify_assignment / notify_mentions
│   │   ├── email.py          # send_email() — logging stub
│   │   ├── task_labels.py    # set_task_labels() with tenancy validation
│   │   └── workspaces.py     # create_workspace(), user_has_workspace()
│   │
│   └── utils/
│       ├── __init__.py
│       ├── keygen.py         # derive_project_key(), unique_project_key()
│       └── position.py       # next_position(), position_between()
│
└── tests/                    # pytest suite (166 tests)
    ├── __init__.py
    ├── conftest.py           # Fixtures: test_engine, client, raw_client, register_client
    ├── test_health.py        # /health
    ├── test_keygen.py        # key derivation (unit)
    ├── test_position.py      # fractional ranks (unit)
    ├── test_projects.py      # project CRUD, keys, counts
    ├── test_tasks.py         # task CRUD, numbers, board, status moves
    ├── test_upcoming.py      # /me/upcoming windows + sorting
    ├── test_filtering.py     # search/status/priority/label/due filters + pagination
    ├── test_reorder.py       # reorder stability
    ├── test_comments.py      # comment CRUD + pagination
    ├── test_labels.py        # label CRUD + assignment + board filter
    ├── test_activity.py      # activity entries created on mutations
    ├── test_archive.py       # archive/unarchive visibility
    ├── test_auth.py          # register/login/refresh/me + failure matrix
    ├── test_teams.py         # two-user invites, roles, workspace switching
    ├── test_assignees_notifications.py  # assignment + mention notifications
    ├── test_workspace_isolation.py      # cross-workspace 404s (Phase 1 resources)
    ├── test_phase2_isolation.py         # cross-workspace 404s (comments/labels/activity)
    ├── test_hardening.py     # error envelope, request id, rate limit, clamps
    └── test_seed_demo.py     # demo seeder + idempotency
```

### Frontend — `frontend/`

Only the app's own source is listed (generated platform folders like
`android/`, `ios/`, `web/`, `windows/`, and `build/` are omitted).

```
frontend/
├── pubspec.yaml              # Dart/Flutter dependencies
│
├── lib/
│   ├── main.dart             # App entry; builds session + ApiClient + provider graph
│   ├── config.dart           # AppConfig.apiBaseUrl (per-platform + --dart-define)
│   │
│   ├── models/               # Plain data classes with fromJson
│   │   ├── app_user.dart     # AppUser (id, email, name)
│   │   ├── workspace.dart    # Workspace (+ isOwner) and Member
│   │   ├── project.dart      # Project (+ counts, archived)
│   │   ├── task.dart         # Task (+ key, labels, isOverdue) + status/priority consts
│   │   ├── label.dart        # Label
│   │   ├── comment.dart      # Comment
│   │   ├── activity.dart     # Activity (+ describe())
│   │   └── notification.dart # AppNotification
│   │
│   ├── services/             # API/session layer
│   │   ├── api_client.dart        # HTTP wrapper: headers, 401→refresh→replay, errors
│   │   ├── session.dart           # SessionController (tokens + active workspace)
│   │   ├── token_storage.dart     # flutter_secure_storage wrapper
│   │   ├── auth_service.dart      # register/login
│   │   ├── workspaces_service.dart# workspaces, members, invites, roles
│   │   ├── projects_service.dart  # projects
│   │   ├── tasks_service.dart     # tasks, board, reorder, labels
│   │   ├── labels_service.dart    # labels
│   │   ├── comments_service.dart  # comments
│   │   ├── activity_service.dart  # activity log
│   │   ├── me_service.dart        # /me/upcoming
│   │   └── notifications_service.dart  # notifications
│   │
│   ├── providers/            # ChangeNotifier state
│   │   ├── projects_provider.dart      # project list + archive toggle
│   │   ├── upcoming_provider.dart      # My Tasks list + window/mine toggles
│   │   ├── labels_provider.dart        # workspace labels
│   │   ├── notifications_provider.dart # notifications + unread count
│   │   └── board_provider.dart         # one project's board (per-screen)
│   │
│   ├── screens/              # Full pages
│   │   ├── auth_gate.dart          # Routes on session status
│   │   ├── login_screen.dart       # Login form
│   │   ├── register_screen.dart    # Registration form
│   │   ├── home_shell.dart         # App bar (switcher, bell, account) + bottom nav
│   │   ├── projects_list_screen.dart  # ProjectsListView (body-only)
│   │   ├── board_screen.dart       # Kanban board + filters + drag/drop
│   │   ├── task_detail_screen.dart # Details/Activity tabs, assignee, labels, comments
│   │   ├── my_tasks_screen.dart    # MyTasksView (body-only)
│   │   ├── members_screen.dart     # Members list + invite (owner)
│   │   └── notifications_screen.dart  # Notifications list + deep link
│   │
│   └── widgets/              # Reusable UI
│       ├── task_card.dart          # Board card
│       ├── label_chip.dart         # Colored label chip (+ labelColor())
│       ├── comments_section.dart   # Comments panel (self-contained)
│       └── activity_timeline.dart  # Activity list (self-contained)
│
└── test/
    └── widget_test.dart      # Boot smoke test (mock client + mock storage)
```

## Dependencies

### Backend runtime — `requirements.txt`

| Package | Purpose | Chapter |
|---------|---------|---------|
| `fastapi` | Web framework: routing, DI, validation, OpenAPI | [5](05-backend-foundation.md) |
| `uvicorn[standard]` | ASGI server that runs the app | [4](04-getting-started.md) |
| `sqlmodel` | ORM + Pydantic models (the tables) | [6](06-data-model-and-migrations.md) |
| `alembic` | Database migrations | [6](06-data-model-and-migrations.md) |
| `pydantic-settings` | Env-driven configuration | [15](15-configuration-reference.md) |
| `psycopg2-binary` | PostgreSQL driver (ships wheels) | [17](17-deployment.md) |
| `email-validator` | Validates `EmailStr` in auth/invite schemas | [7](07-auth-and-multitenancy.md) |
| `python-jose[cryptography]` | JWT encode/decode | [7](07-auth-and-multitenancy.md) |
| `bcrypt` | Password hashing (used directly) | [7](07-auth-and-multitenancy.md) |
| `slowapi` | Rate limiting on auth endpoints | [5](05-backend-foundation.md) |
| `python-multipart` | Form parsing support for FastAPI | — |

### Backend dev/test — `requirements-dev.txt`

| Package | Purpose |
|---------|---------|
| `pytest` | Test runner |
| `pytest-cov` | Coverage reporting |
| `httpx` | HTTP client used by FastAPI's `TestClient` |
| `faker` | Test data generation helper |

### Frontend — `pubspec.yaml`

| Package | Purpose | Chapter |
|---------|---------|---------|
| `provider` | State management (`ChangeNotifier`) | [12](12-frontend-models-services-state.md) |
| `http` | HTTP client used by `ApiClient` | [11](11-frontend-architecture.md) |
| `intl` | Date formatting | [13](13-frontend-screens-widgets.md) |
| `flutter_secure_storage` | Encrypted token storage | [11](11-frontend-architecture.md) |
| `cupertino_icons` | iOS-style icon font (default) | — |
| `flutter_lints` (dev) | Recommended lint rules | [16](16-testing.md) |

## CLI cheat sheet

### Backend

```bash
# Environment
python -m venv .venv && source .venv/bin/activate   # (Windows: .venv\Scripts\Activate.ps1)
pip install -r requirements-dev.txt

# Database / migrations
alembic upgrade head            # build/upgrade schema
alembic downgrade -1            # roll back one
alembic current                 # show applied revision
alembic history                 # list the chain
alembic revision -m "message"   # scaffold a new migration

# Run the API
uvicorn app.main:app --reload                 # dev
uvicorn app.main:app --host 0.0.0.0 --port 8000  # prod-ish

# Demo data
python -m app.seed              # seed (schema must exist)
python -m app.seed --reset      # drop+recreate schema, then seed (throwaway DBs)

# Tests
pytest                          # all
pytest -k <name>                # subset
pytest --cov=app --cov-report=term-missing
pytest --cov=app --cov-report=html   # → htmlcov/
```

### Frontend

```bash
flutter pub get                                   # fetch deps
flutter run -d chrome                             # run (web)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000   # override API URL
flutter analyze                                   # static analysis
flutter test                                      # widget tests
flutter build web --release --dart-define=API_BASE_URL=https://api.example.com
flutter build windows --release
flutter build apk --release
```

### Docker

```bash
docker compose up --build                         # api + Postgres
SECRET_KEY=$(openssl rand -hex 32) docker compose up --build
SEED_DEMO=true SECRET_KEY=... docker compose up --build
docker compose up -d db                           # just the database (for local dev)
docker compose config                             # validate the compose file
```

## Version history

Korvexa was built in five phases, one git commit each.

| Commit | Phase | Summary |
|--------|-------|---------|
| `d5553d7` | 0 — Scaffolding | Repo layout, Alembic + initial migration, `/health`, pytest wiring, Flutter boot, docker-compose Postgres |
| `612a33f` | 1 — Core MVP | Seeded single user/workspace; projects & tasks CRUD; auto-derived keys; per-project task numbers; board; `/me/upcoming`; Flutter list/board/edit/my-tasks |
| `f79f756` | 2 — Depth & polish | Comments, workspace labels, search/filter, within-column reorder, activity log, project archive, pagination; frontend detail/comments/labels/filters/reorder/activity |
| `cabf268` | 3 — Teams & auth | JWT auth, the workspace seam rewrite, multi-workspace + switcher, invites, roles, assignees, in-app notifications; frontend auth, secure storage, refresh interceptor, members, notifications |
| `065074b` | 4 — Hardening & ship | Consistent error envelope, request-id logging, auth rate limiting, Dockerfile + compose, demo seeder, OpenAPI polish, deploy notes, ~92% coverage |

Each phase's tests were green before the next began; the schema builds entirely
from `alembic upgrade head`; and multi-tenant isolation and role permissions are
proven by tests.

---

Previous: [Chapter 20 — Glossary](20-glossary.md) ·
Back to the [Table of Contents](README.md)
