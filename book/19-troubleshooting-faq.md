# 19. Troubleshooting & FAQ

Common problems and their fixes, grouped by area. For a request-specific error,
grab the `request_id` from the error body (or the `X-Request-ID` response
header) and grep the server logs for `req:<id>`.

## Backend setup

**`pydantic-core` (or another wheel) fails to build on Windows.**
You're likely using an MSYS2/MinGW Python that reports a non-standard platform
tag. Create the virtualenv with the standard **python.org** interpreter (the one
that produces a `.venv\Scripts\` layout) and reinstall.

**`alembic: command not found` / `uvicorn: command not found`.**
The virtualenv isn't activated. Activate it (`.venv\Scripts\Activate.ps1` or
`source .venv/bin/activate`) and retry.

**`alembic upgrade head` does nothing / "target database is not up to date".**
Check `alembic current` vs `alembic history`. If you switched `DATABASE_URL` to
a fresh database, run `alembic upgrade head` again against it — migrations are
per-database.

**Foreign-key deletes don't cascade on SQLite.**
SQLite disables FK enforcement per connection. Korvexa enables it via a
`PRAGMA foreign_keys=ON` event in [`db.py`](../backend/app/db.py); if you built a
custom engine, replicate that. See [Chapter 5](05-backend-foundation.md#database-engine--session--dbpy).

## Auth & permissions

**Every API call returns `401`.**
Either you're not sending `Authorization: Bearer <access>`, or the access token
expired and the refresh also failed. In the app this routes you back to login;
with `curl`, log in again to get a fresh pair.

**A request returns `404` for a resource I'm sure exists.**
That's the isolation behavior: you requested a resource in a workspace you don't
belong to (or under the wrong `X-Workspace-Id`). Korvexa returns `404` rather
than `403` so tenants can't probe each other. Check your `X-Workspace-Id` header.

**`403 "Requires workspace owner role"`.**
You're a `member` attempting an owner-only action (delete a project, manage
members). Ask an owner, or get promoted via `PATCH /workspaces/{id}/members/{user_id}`.

**"Refresh token" rejected with `401` even though it looks valid.**
Make sure you're sending the **refresh** token to `/auth/refresh`, not the access
token — the endpoint enforces the token `type`.

**I rotated `SECRET_KEY` and everyone got logged out.**
Expected: all previously issued tokens were signed with the old key and no longer
validate. Users just log in again.

## Tasks & board

**Assigning a task returns `400 "Assignee is not a member of this workspace"`.**
The `assignee_id` must belong to a member of the task's workspace. Invite them
first, or pick an existing member.

**Adding a label returns `400 "Unknown label id(s) for this workspace"`.**
You passed a label id that doesn't exist or belongs to another workspace. Labels
are workspace-scoped — create the label in this workspace first.

**A duplicate project key or label name returns `409`.**
Keys are unique per workspace, and label names are unique per workspace. Choose a
different value (or let the project key auto-derive).

**Reordering seems to move the wrong way with only one neighbor.**
Remember the semantics: `before_id` is the card the moved task should end up
**before** (its successor); `after_id` is the card it should end up **after** (its
predecessor). See [Chapter 8](08-projects-tasks-board.md#reordering-fractional-ranks).

## Frontend

**The app shows a network error / spinner forever.**
The backend isn't reachable at the configured `API_BASE_URL`. On the Android
emulator use `http://10.0.2.2:8000` (not `127.0.0.1`); on web/desktop use
`127.0.0.1`. Override with `--dart-define=API_BASE_URL=…`.

**CORS errors in the browser console (web build).**
Set `CORS_ORIGINS` on the backend to include your web app's exact origin, e.g.
`CORS_ORIGINS=["http://localhost:5000"]` (or your deployed origin). The default
`["*"]` works for quick local testing.

**`flutter build web --wasm` fails with a `dart:js_util` error.**
`flutter_secure_storage_web` isn't Wasm-compatible. Use the default JS build
(`flutter build web --release`), not `--wasm`.

**Switching workspaces still shows old data.**
The shell reloads all workspace-scoped providers on switch; if you added a new
provider, wire it into `_switchWorkspace` in
[`home_shell.dart`](../frontend/lib/screens/home_shell.dart).

## Tests

**The suite is slow.**
Expected — each test builds its DB from the migration chain (the isolation
guarantee) and hashes a password on registration. `BCRYPT_ROUNDS=4` is already
set for tests; you can run a subset with `pytest -k <name>`.

**`flutter test` fails with a `MissingPluginException` for secure storage.**
Call `FlutterSecureStorage.setMockInitialValues({})` in the test's `setUp` (the
existing widget test does this).

## FAQ

**Can I run without Docker or Postgres?**
Yes — the default `DATABASE_URL` is a local SQLite file. Just
`alembic upgrade head` + `uvicorn`.

**How do I get demo data?**
Run `python -m app.seed` (schema must exist), or set `SEED_DEMO=true` when
starting the container. Credentials are in
[Chapter 15](15-configuration-reference.md#demo-seed-identities).

**How do I add a new table/field?**
Add/modify the SQLModel in `app/models`, then write a new Alembic migration in
`alembic/versions` chaining from the current head, and run `alembic upgrade head`.
Never rely on `create_all`. See [Chapter 6](06-data-model-and-migrations.md).

**How do I add a new endpoint?**
Add a function to the relevant router (or a new router included in
`main.py`), depend on `get_current_workspace`/`get_current_user`/`require_owner`
as needed, define request/response schemas in `app/schemas`, and add tests. The
existing routers are the template.

**Where do I change token lifetimes or the rate limit?**
Env vars: `ACCESS_TOKEN_EXPIRE_MINUTES`, `REFRESH_TOKEN_EXPIRE_MINUTES`,
`RATE_LIMIT_AUTH`. See [Chapter 15](15-configuration-reference.md).

**Is email actually sent?**
No — it's a logging stub. See [Chapter 10](10-assignments-notifications.md#email-stub--servicesemailpy).

---

Previous: [Chapter 18 — Security Considerations](18-security.md) ·
Next: [Chapter 20 — Glossary](20-glossary.md)
