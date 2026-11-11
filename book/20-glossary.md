# 20. Glossary

Project-specific terms, plus the third-party technologies you'll meet in the
code. Cross-references point to where each is explained in depth.

## Korvexa domain terms

**Workspace** — the tenant boundary. Every project, label, and notification
belongs to exactly one workspace. A user can belong to several.
See [Chapter 6](06-data-model-and-migrations.md), [Chapter 7](07-auth-and-multitenancy.md).

**Membership** — the link between a user and a workspace, carrying a **role**.
Uniqueness is enforced: a user joins a workspace at most once.

**Role** — `owner` or `member`. Owners can delete projects and manage members;
members can do everything else. See [Chapter 7](07-auth-and-multitenancy.md#role-enforcement).

**Project key** — a short uppercase code (e.g. `ACME`) unique within a
workspace, auto-derived from the project name if not supplied.
See [Chapter 8](08-projects-tasks-board.md#creating-a-project--the-key).

**Task number / task key** — each task has a per-project sequential `number`;
combined with the project key it forms the human-readable **task key** like
`ACME-42`. The `number` comes from the project's stored `task_counter`.

**Position (fractional rank)** — a float used to order tasks within a status
column. Inserting between two cards uses the midpoint, so reordering writes one
row. See [Chapter 8](08-projects-tasks-board.md#reordering-fractional-ranks).

**Board** — a task list grouped into the three status columns (`todo`,
`in_progress`, `done`).

**The seam** — the single dependency (`get_current_workspace` in
[`deps.py`](../backend/app/deps.py)) that resolves the active workspace. Rewriting
only it turned Korvexa from single-user into multi-tenant.
See [Chapter 3](03-architecture.md#the-team-later-seam-why-the-design-scales),
[Chapter 7](07-auth-and-multitenancy.md).

**Invite placeholder** — a passwordless `users` row created when you invite an
unknown email. It's "claimed" (name + password set) when that person registers.
See [Chapter 7](07-auth-and-multitenancy.md#invites).

**Activity log** — the append-only per-task history of `created` /
`status_changed` / `updated` events. See [Chapter 9](09-comments-labels-activity.md#activity-log--routersactivitypy).

**Mention** — an `@handle` in a comment that notifies a matching workspace
member. See [Chapter 10](10-assignments-notifications.md#mentions).

**Error envelope** — the uniform JSON error shape `{ detail, request_id }` (plus
`errors` for validation). See [Chapter 5](05-backend-foundation.md#error-envelope--request-ids--errorspy).

**Request id** — a per-request identifier, generated or taken from an inbound
`X-Request-ID`, echoed in the response header and stamped on log lines.

**Phase (0–4)** — the five build increments, one git commit each.
See [Chapter 1](01-introduction.md#the-phases-youll-see-referenced) and the
[Appendix](21-appendix.md#version-history).

## Technologies

**FastAPI** — the Python web framework the backend is built on. Provides routing,
dependency injection (`Depends`), validation, and automatic OpenAPI docs.

**SQLModel** — a library that unifies SQLAlchemy (ORM/tables) and Pydantic
(validation). One class defines a table. Used for all models.

**SQLAlchemy** — the underlying ORM/engine. Korvexa uses it **synchronously**.

**Alembic** — the database migration tool. `alembic upgrade head` builds the
schema; migrations are the source of truth. See [Chapter 6](06-data-model-and-migrations.md).

**pydantic-settings** — loads and validates configuration from env vars / `.env`.
See [Chapter 15](15-configuration-reference.md).

**Uvicorn** — the ASGI server that runs the FastAPI app.

**JWT (JSON Web Token)** — the signed token format used for auth. Korvexa issues
`access` and `refresh` types, signed with HS256 via **python-jose**.

**bcrypt** — the password-hashing algorithm/library (used directly, not via
passlib). See [Chapter 7](07-auth-and-multitenancy.md#passwords-bcrypt).

**slowapi** — the rate-limiting library applied to auth endpoints.

**Flutter / Dart** — the UI toolkit and language for the client app.

**provider** — the Flutter state-management package. State lives in
`ChangeNotifier` classes that widgets watch. See [Chapter 12](12-frontend-models-services-state.md).

**flutter_secure_storage** — encrypted key/value storage for tokens on the
client. See [Chapter 11](11-frontend-architecture.md#secure-storage--token_storagedart).

**ChangeNotifier** — the Flutter base class that notifies listeners of state
changes; every provider extends it.

**DragTarget / Draggable** — Flutter's built-in drag-and-drop widgets used to
build the board without an extra package. See [Chapter 13](13-frontend-screens-widgets.md#drag-and-drop-model).

## HTTP terms used in this book

**Bearer token** — an access token sent as `Authorization: Bearer <token>`;
possession grants access.

**`X-Workspace-Id`** — the request header that selects the active workspace.

**`Page` envelope** — the pagination wrapper `{ items, total, limit, offset }`
returned by list endpoints. See [Chapter 8](08-projects-tasks-board.md#pagination).

**Cascade** — a foreign-key rule (`ON DELETE CASCADE`) that deletes child rows
when a parent is deleted.

---

Previous: [Chapter 19 — Troubleshooting & FAQ](19-troubleshooting-faq.md) ·
Next: [Chapter 21 — Appendix](21-appendix.md)
