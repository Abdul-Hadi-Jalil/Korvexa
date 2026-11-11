# 2. Project Overview

## What Korvexa is

Korvexa is a **Jira-style task manager**: workspaces contain projects, projects
contain tasks, and tasks move across a Kanban board (To Do → In Progress →
Done). It is designed to be **self-hostable** and to work equally well for a
single user or a small team.

The defining design decision is that it was built to run great for one user
**and cleanly scale to a team later** — without a rewrite. Every piece of data
is scoped to a workspace from day one, so turning on real multi-user auth was a
matter of swapping a single dependency (see [Chapter 7](07-auth-and-multitenancy.md)).

## Key features

**Projects & tasks**
- Projects with an auto-derived short **key** (e.g. `Marketing` → `MARK`) and
  open/total task counts.
- Tasks with a per-project sequential **number**, forming human-readable keys
  like `MARK-42`.
- A **Kanban board** grouped by status, with drag-and-drop between columns and
  drag-to-reorder within a column (backed by a fractional-rank `position` so
  moving one card never renumbers the others).
- Status, priority, due date, description, and assignee per task.

**Collaboration**
- **Comments** on tasks (author + timestamps, editable/deletable by the author).
- Workspace-scoped **labels**, assignable to tasks and usable as board filters.
- Per-task **activity log** (created, status change, field edits).
- **Search & filter** tasks by text, status, priority, label, and due window.
- Project **archive/unarchive** (archived hidden by default).

**Teams & auth**
- Register / login with **JWT access + refresh tokens**; bcrypt password hashing.
- **Multiple workspaces per user** with a switcher.
- **Invite by email**, membership **roles** (`owner` / `member`), and role
  enforcement (only an owner can delete a project or manage members).
- **Assignees** drawn from workspace members; a "My Tasks" view filtered to the
  current user.
- **In-app notifications** on assignment and on `@mention` in a comment (email
  delivery is a logged stub).

**Operations**
- One consistent JSON **error envelope** and **request-id** logging.
- **Rate limiting** on auth endpoints.
- **Migrations as the source of truth** — the schema is always built by
  `alembic upgrade head`, never `create_all` in production.
- Runs unchanged on **SQLite, PostgreSQL, or Supabase** by changing one env var.

## Tech stack

| Layer | Technology | Why |
|-------|-----------|-----|
| Backend framework | **FastAPI** | Async-capable, typed, automatic OpenAPI docs |
| ORM / models | **SQLModel** (SQLAlchemy + Pydantic) | One class is both the table and the schema base |
| Migrations | **Alembic** | Versioned, DB-agnostic schema evolution |
| Server | **Uvicorn** | ASGI server |
| Config | **pydantic-settings** | Env-driven settings with validation |
| Auth | **python-jose** (JWT) + **bcrypt** | Standard token + password hashing |
| Rate limiting | **slowapi** | Per-IP throttling of auth endpoints |
| Database | **SQLite / PostgreSQL / Supabase** | Dev-to-prod without code changes |
| Frontend | **Flutter (Dart 3)** | One codebase for web, desktop, mobile |
| FE state | **provider** | Lightweight `ChangeNotifier` state management |
| FE networking | **http** | Simple typed HTTP client |
| FE storage | **flutter_secure_storage** | Encrypted token storage |
| FE dates | **intl** | Date formatting |

The exact versions live in [`backend/requirements.txt`](../backend/requirements.txt)
and [`frontend/pubspec.yaml`](../frontend/pubspec.yaml); each dependency's role
is listed in the [Appendix](21-appendix.md#dependencies).

## Target users

- **Individuals** who want a private, self-hosted task board.
- **Small teams** who want shared workspaces, assignments, and notifications
  without a heavyweight SaaS tool.
- **Developers/learners** who want a compact but realistic reference app.

## Repository shape

```
korvexa/
├── backend/      # FastAPI application (Python)
├── frontend/     # Flutter application (Dart)
├── docker-compose.yml   # api + Postgres for self-hosting
├── README.md            # top-level quickstart
└── book/                # this book
```

The two halves communicate over HTTP with JSON. The frontend sends a bearer
token and an `X-Workspace-Id` header; the backend authenticates the user,
resolves the active workspace, and enforces that the user is a member. That
contract is the subject of [Chapter 3](03-architecture.md).

---

Previous: [Chapter 1 — Introduction](01-introduction.md) ·
Next: [Chapter 3 — Architecture](03-architecture.md)
