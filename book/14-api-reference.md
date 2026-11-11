# 14. API Reference

The complete HTTP API. Base URL defaults to `http://127.0.0.1:8000`. Interactive
docs are always available at **`/docs`** (Swagger UI) and **`/openapi.json`**.

## Conventions

- **Auth** — unless noted, every endpoint requires
  `Authorization: Bearer <access_token>`. Most also use the active workspace,
  selected by an `X-Workspace-Id: <id>` header (falls back to your first
  workspace if omitted). See [Chapter 7](07-auth-and-multitenancy.md).
- **Auth column** below: `—` = no auth; `user` = any logged-in user; `member` =
  member of the workspace; `owner` = workspace owner; `author` = the resource's
  author.
- **Errors** share one envelope (see [Chapter 5](05-backend-foundation.md#error-envelope--request-ids--errorspy)):
  ```json
  { "detail": "<message>", "request_id": "<id>" }
  ```
  Validation errors are `422` with an added `errors` array. Every response
  carries an `X-Request-ID` header.
- **Isolation** — requesting a resource in a workspace you don't belong to (or
  that doesn't exist) returns `404`, never `403` — you can't tell the difference.

## Endpoint summary

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/health` | — | Liveness probe |
| POST | `/auth/register` | — | Create account + personal workspace |
| POST | `/auth/login` | — | Log in |
| POST | `/auth/refresh` | — | New token pair from a refresh token |
| GET | `/auth/me` | user | Current user |
| GET | `/workspaces` | user | Workspaces you belong to |
| POST | `/workspaces` | user | Create a workspace |
| GET | `/workspaces/{id}/members` | member | List members |
| POST | `/workspaces/{id}/invite` | owner | Invite by email |
| PATCH | `/workspaces/{id}/members/{user_id}` | owner | Change a member's role |
| DELETE | `/workspaces/{id}/members/{user_id}` | owner | Remove a member |
| GET | `/projects` | member | List projects |
| POST | `/projects` | member | Create a project |
| GET | `/projects/{id}` | member | Get a project |
| PATCH | `/projects/{id}` | member | Update a project |
| POST | `/projects/{id}/archive` | member | Archive |
| POST | `/projects/{id}/unarchive` | member | Unarchive |
| DELETE | `/projects/{id}` | owner | Delete a project |
| GET | `/projects/{id}/tasks` | member | List tasks (paginated, filterable) |
| GET | `/projects/{id}/board` | member | Board grouped by status |
| POST | `/projects/{id}/tasks` | member | Create a task |
| GET | `/tasks/{id}` | member | Get a task |
| PATCH | `/tasks/{id}` | member | Update / move a task |
| POST | `/tasks/{id}/reorder` | member | Reorder within a column |
| PUT | `/tasks/{id}/labels` | member | Replace a task's labels |
| DELETE | `/tasks/{id}` | member | Delete a task |
| GET | `/tasks/{id}/comments` | member | List comments (paginated) |
| POST | `/tasks/{id}/comments` | member | Add a comment |
| PATCH | `/comments/{id}` | author | Edit a comment |
| DELETE | `/comments/{id}` | author | Delete a comment |
| GET | `/tasks/{id}/activity` | member | Task activity log |
| GET | `/labels` | member | List labels |
| POST | `/labels` | member | Create a label |
| PATCH | `/labels/{id}` | member | Update a label |
| DELETE | `/labels/{id}` | member | Delete a label |
| GET | `/me/upcoming` | member | Cross-project open tasks |
| GET | `/notifications` | member | Your notifications |
| GET | `/notifications/unread_count` | member | Unread count |
| POST | `/notifications/{id}/read` | user | Mark one read |
| POST | `/notifications/read_all` | member | Mark all read |

---

## Health

### `GET /health`
No auth. → `200 { "status": "ok" }`.

---

## Auth

Router: [`routers/auth.py`](../backend/app/routers/auth.py). `register` and
`login` are **rate-limited** (default `10/minute` per IP → `429` when exceeded).

### `POST /auth/register`
```json
// request
{ "email": "a@example.com", "name": "Alice", "password": "min-8-chars" }
// 201 response
{ "access_token": "…", "refresh_token": "…", "token_type": "bearer" }
```
- `409` if the email already has a password. If the email is an invite
  placeholder (no password), this **claims** it.

### `POST /auth/login`
```json
{ "email": "a@example.com", "password": "…" }   // → 200 TokenPair
```
- `401 "Invalid email or password"` (same message for unknown email or wrong
  password).

### `POST /auth/refresh`
```json
{ "refresh_token": "…" }   // → 200 TokenPair
```
- `401` if the token is invalid, expired, or not of type `refresh`.

### `GET /auth/me`
→ `200 { "id", "email", "name", "created_at" }`. `401` if unauthenticated.

---

## Workspaces & members

Router: [`routers/workspaces.py`](../backend/app/routers/workspaces.py). These
take the workspace id **in the path**.

### `GET /workspaces`
→ list of `{ "id", "name", "owner_id", "created_at", "role" }` (your role in each).

### `POST /workspaces`
```json
{ "name": "Acme" }   // → 201 WorkspaceRead (you become owner)
```

### `GET /workspaces/{id}/members`
→ list of `{ "user_id", "email", "name", "role", "membership_id" }`. `404` if
you're not a member.

### `POST /workspaces/{id}/invite` — owner only
```json
{ "email": "bob@example.com", "role": "member" }   // → 201 MemberRead
```
- `403` if not owner; `409` if already a member; `422` for an invalid role.
- Unknown emails create a passwordless placeholder account.

### `PATCH /workspaces/{id}/members/{user_id}` — owner only
```json
{ "role": "owner" }   // → 200 MemberRead
```

### `DELETE /workspaces/{id}/members/{user_id}` — owner only
→ `204`. `400` if an owner tries to remove themselves.

---

## Projects

Router: [`routers/projects.py`](../backend/app/routers/projects.py).
`ProjectRead` = `{ id, workspace_id, name, key, description, color, archived, created_at, open_tasks, total_tasks }`.

### `GET /projects?include_archived=false`
→ list of `ProjectRead` (archived hidden unless `include_archived=true`).

### `POST /projects`
```json
{ "name": "Acme", "key": "ACME", "description": "…", "color": "#4433ff" }
```
- `name` required; `key` optional (auto-derived + de-duplicated if omitted,
  uppercased if given). `409` if a given key already exists in the workspace.

### `GET /projects/{id}` · `PATCH /projects/{id}`
- PATCH body (all optional): `{ "name", "description", "color" }`.

### `POST /projects/{id}/archive` · `POST /projects/{id}/unarchive`
→ `200 ProjectRead` with `archived` toggled.

### `DELETE /projects/{id}` — owner only
→ `204`. Cascades to the project's tasks. `403` for non-owners.

---

## Tasks & board

Router: [`routers/tasks.py`](../backend/app/routers/tasks.py).
`TaskRead` = `{ id, project_id, number, key, title, description, status, priority, assignee_id, due_date, position, created_at, updated_at, labels: [LabelRead] }`.

### `GET /projects/{id}/tasks`
Query params: `q`, `status`, `priority`, `label_id`, `due` (`overdue|today|week`),
`limit` (1–200, default 50), `offset` (≥0). → **`Page[TaskRead]`**:
```json
{ "items": [ TaskRead ], "total": 42, "limit": 50, "offset": 0 }
```

### `GET /projects/{id}/board`
Query params: `q`, `priority`, `label_id`, `due` (no `status` — it's the grouping
key). →
```json
{ "todo": [TaskRead], "in_progress": [TaskRead], "done": [TaskRead] }
```

### `POST /projects/{id}/tasks`
```json
{ "title": "Ship it", "description": "…", "status": "todo",
  "priority": "medium", "assignee_id": 3, "due_date": "2026-08-01",
  "label_ids": [1, 2] }   // → 201 TaskRead
```
- Only `title` is required. `422` for invalid enum values. `400` if the assignee
  isn't a workspace member. Assigning fires a notification.

### `GET /tasks/{id}` · `PATCH /tasks/{id}` · `DELETE /tasks/{id}`
- PATCH body (all optional): `title`, `description`, `status`, `priority`,
  `assignee_id`, `due_date`, `position`. Changing `status` to a new column
  appends to its end unless `position` is given; tracked field changes are logged
  to the activity log; an assignee change may notify.

### `POST /tasks/{id}/reorder`
```json
{ "position": 1536.0 }               // explicit, OR
{ "before_id": 9, "after_id": 4 }    // place between neighbors
```
- `400` if a sibling id is in a different project. Writes only this task's row.

### `PUT /tasks/{id}/labels`
Body is a **bare JSON array** of label ids: `[1, 2]` → `200 TaskRead`. Replaces
the whole set. `400` for a label id not in this workspace.

---

## Comments

Router: [`routers/comments.py`](../backend/app/routers/comments.py).

### `GET /tasks/{id}/comments?limit=50&offset=0`
→ `Page[CommentRead]`, `CommentRead` = `{ id, task_id, author_id, author_name, body, created_at, updated_at }`.

### `POST /tasks/{id}/comments`
```json
{ "body": "hey @bob take a look" }   // → 201 CommentRead
```
- `@mentions` of workspace members create notifications.

### `PATCH /comments/{id}` · `DELETE /comments/{id}` — author only
- `403` if you're not the author.

---

## Activity

### `GET /tasks/{id}/activity`
→ list of `{ id, task_id, actor_id, action, field, old_value, new_value, created_at }`,
newest first. `action` ∈ `created | status_changed | updated`.

---

## Labels

Router: [`routers/labels.py`](../backend/app/routers/labels.py).
`LabelRead` = `{ id, workspace_id, name, color, created_at }`.

### `GET /labels` · `POST /labels` · `PATCH /labels/{id}` · `DELETE /labels/{id}`
- Create/rename: `{ "name": "bug", "color": "#e53935" }`. `409` on a duplicate
  name in the workspace. Delete cascades the label off all tasks.

---

## Me (cross-project)

### `GET /me/upcoming?window=all&mine=false`
- `window` ∈ `today | week | all`. `mine=true` restricts to tasks assigned to
  you. → list of `TaskWithProjectRead` (a `TaskRead` plus `project_name`,
  `project_key`). Always excludes `done`, always includes overdue; sorted by due
  date then priority. See [Chapter 8](08-projects-tasks-board.md#my-tasks--upcoming--routersmepy).

---

## Notifications

Router: [`routers/notifications.py`](../backend/app/routers/notifications.py).
`NotificationRead` = `{ id, type, task_id, comment_id, actor_id, message, read, created_at }`.

### `GET /notifications?unread_only=false`
→ your notifications in the active workspace, newest first.

### `GET /notifications/unread_count`
→ `{ "unread": 3 }`.

### `POST /notifications/{id}/read`
→ `200 NotificationRead`. `404` if it isn't yours.

### `POST /notifications/read_all`
→ `{ "marked": 3 }` (count marked read in the active workspace).

---

Previous: [Chapter 13 — Frontend Screens & Widgets](13-frontend-screens-widgets.md) ·
Next: [Chapter 15 — Configuration Reference](15-configuration-reference.md)
