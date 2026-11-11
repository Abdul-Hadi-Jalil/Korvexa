# 3. Architecture

This chapter is the map. It shows the major components, how a request travels
end to end, and the one design idea — the **workspace seam** — that shapes the
whole backend. Deep dives for each component are linked inline.

## High-level system design

Korvexa is a classic two-tier app: a Flutter client talks to a FastAPI server
over HTTP/JSON, and the server persists to a SQL database.

```mermaid
graph TD
    subgraph Client["Flutter app (web / desktop / mobile)"]
        UI["Screens & Widgets"]
        State["Providers (ChangeNotifier)"]
        Session["SessionController<br/>(tokens + active workspace)"]
        API["ApiClient<br/>(injects auth + workspace headers,<br/>refreshes on 401)"]
        Store["TokenStorage<br/>(flutter_secure_storage)"]
        UI --> State --> API
        Session --> API
        Session --> Store
    end

    subgraph Server["FastAPI backend"]
        MW["Middleware<br/>(request id, CORS)"]
        Handlers["Exception handlers<br/>(consistent error envelope)"]
        Deps["Dependencies<br/>get_current_user / get_current_workspace"]
        Routers["Routers<br/>(auth, workspaces, projects, tasks, ...)"]
        Services["Services<br/>(serialization, notifications, activity, ...)"]
        ORM["SQLModel ORM"]
        MW --> Routers
        Routers --> Deps
        Routers --> Services
        Routers --> ORM
    end

    DB[("Database<br/>SQLite / Postgres / Supabase")]
    Alembic["Alembic migrations<br/>(schema source of truth)"]

    API -->|"Bearer token +<br/>X-Workspace-Id"| MW
    ORM --> DB
    Alembic -.->|"alembic upgrade head"| DB
```

The client never talks to the database directly. It holds tokens and the active
workspace id, and attaches them to every request. The server decides — on every
request — *who* you are and *which workspace* you're acting in, then enforces
that you're a member of it.

## Backend component map

The backend is organized by responsibility. Each folder is a layer:

```mermaid
graph LR
    main["main.py<br/>app assembly"]

    subgraph core["app/core"]
        config["config.py"]
        security["security.py"]
        logging["logging.py"]
        errors["errors.py"]
        ratelimit["rate_limit.py"]
    end

    deps["deps.py<br/>(the seam)"]

    subgraph routers["app/routers"]
        r["auth · workspaces · projects<br/>tasks · labels · comments<br/>activity · notifications · me · health"]
    end

    subgraph services["app/services"]
        s["serialization · activity<br/>notifications · email<br/>task_labels · workspaces"]
    end

    subgraph models["app/models"]
        m["User · Workspace · Membership<br/>Project · Task · Label · TaskLabel<br/>Comment · ActivityLog · Notification"]
    end

    subgraph schemas["app/schemas"]
        sc["request/response DTOs"]
    end

    utils["app/utils<br/>keygen · position"]
    db["db.py<br/>engine + session"]
    alembic["alembic/<br/>migrations"]

    main --> routers
    main --> core
    routers --> deps
    routers --> services
    routers --> schemas
    routers --> models
    services --> models
    deps --> models
    models --> db
    utils --> routers
    alembic -.-> models
```

Chapter map for these components:

- `main.py`, `core/*`, `db.py` → [Chapter 5](05-backend-foundation.md)
- `models/*`, `alembic/*` → [Chapter 6](06-data-model-and-migrations.md)
- `deps.py`, `security.py`, auth & workspaces routers → [Chapter 7](07-auth-and-multitenancy.md)
- projects/tasks/me routers, serialization, utils → [Chapter 8](08-projects-tasks-board.md)
- comments/labels/activity → [Chapter 9](09-comments-labels-activity.md)
- notifications, assignments, email → [Chapter 10](10-assignments-notifications.md)

## The layered pattern inside the backend

Every feature follows the same vertical slice:

```mermaid
graph TD
    Request["HTTP request"] --> Router["Router function<br/>(app/routers/*.py)"]
    Router --> Dep["Depends(...)<br/>get_session, get_current_user,<br/>get_current_workspace, require_owner"]
    Router --> Schema["Pydantic/SQLModel schema<br/>validates the body"]
    Router --> Service["Service helper<br/>(optional: notifications, activity, ...)"]
    Router --> Model["SQLModel table<br/>read/write via Session"]
    Model --> Response["Response schema<br/>serialized back to JSON"]
```

- **Routers** are thin: they validate input, call `Depends` for auth/tenancy,
  do the query, and return a response schema.
- **Schemas** ([`app/schemas`](../backend/app/schemas)) are the request/response
  contracts — separate from the ORM tables so the API surface is deliberate.
- **Services** ([`app/services`](../backend/app/services)) hold logic shared by
  several routers (serializing tasks with their labels, writing activity
  entries, creating notifications) to keep routers small.
- **Models** ([`app/models`](../backend/app/models)) are the SQLModel tables.

## Request lifecycle

Here is what a typical authenticated call — "create a task" — passes through:

```mermaid
sequenceDiagram
    participant App as Flutter ApiClient
    participant MW as RequestContextMiddleware
    participant Router as tasks router
    participant Deps as deps.py
    participant DB as Database

    App->>MW: POST /projects/1/tasks<br/>Authorization: Bearer …<br/>X-Workspace-Id: 1
    MW->>MW: assign request id, start timer
    MW->>Router: forward request
    Router->>Deps: get_current_user (decode JWT)
    Deps->>DB: load User
    Router->>Deps: get_current_workspace (X-Workspace-Id)
    Deps->>DB: check Membership(user, workspace)
    alt not a member
        Deps-->>App: 404 (via error envelope)
    else authorized
        Router->>DB: increment task_counter, insert Task
        Router->>DB: record activity, maybe notify assignee
        DB-->>Router: task row
        Router-->>MW: TaskRead JSON
        MW->>MW: add X-Request-ID header, log line
        MW-->>App: 201 Created
    end
```

The two `Depends` calls are the heart of the security model: **who** (JWT) and
**which workspace** (header + membership check). They are covered in detail in
[Chapter 7](07-auth-and-multitenancy.md).

## Middleware & error handling layers

FastAPI/Starlette wrap the router in a stack. Korvexa configures it (in
[`app/main.py`](../backend/app/main.py)) so that, from outermost to innermost:

```mermaid
graph TD
    A["ServerErrorMiddleware<br/>catches unhandled 500s → error envelope"]
    B["CORSMiddleware"]
    C["RequestContextMiddleware<br/>request id + access log + X-Request-ID"]
    D["ExceptionMiddleware<br/>HTTPException + validation → error envelope"]
    E["Router / endpoint"]
    A --> B --> C --> D --> E
```

Two consequences worth remembering:

- Every response — success or error — leaves with an `X-Request-ID` header, and
  every error body carries a matching `request_id`. See [Chapter 5](05-backend-foundation.md#error-envelope--request-ids--errorspy).
- Because `RequestContextMiddleware` sits *outside* the exception handlers, the
  request id is available both to the handlers and to the access log line.

## The "team-later" seam (why the design scales)

Every table that holds user data has a `workspace_id`. A `memberships` table
records which users belong to which workspace and with what role. All data
access flows through **one dependency**, `get_current_workspace`.

- In **Phase 1–2** the app was single-user: `get_current_workspace` returned
  "the only workspace that exists".
- In **Phase 3** the app became multi-tenant by **rewriting only that
  dependency** to resolve the user from a JWT and the workspace from the
  `X-Workspace-Id` header, enforcing membership. No router code changed — the
  dependency still returns a `Workspace`.

```mermaid
graph LR
    subgraph Before["Phase 1–2 (single user)"]
        b1["get_current_workspace()"] --> b2["the only workspace"]
    end
    subgraph After["Phase 3+ (teams)"]
        a1["get_current_workspace()"] --> a2["JWT user + X-Workspace-Id<br/>→ membership check"]
    end
```

This is the single most important architectural idea in the project. It is
explored fully — with the actual before/after code — in
[Chapter 7](07-auth-and-multitenancy.md).

## Data flow: frontend ↔ backend contract

```mermaid
graph LR
    subgraph Headers["Every authenticated request carries"]
        h1["Authorization: Bearer &lt;access token&gt;"]
        h2["X-Workspace-Id: &lt;id&gt;"]
    end
    subgraph Responses["Every response carries"]
        r1["X-Request-ID: &lt;id&gt;"]
        r2["JSON body or {detail, request_id}"]
    end
    Headers --> Backend[FastAPI]
    Backend --> Responses
```

The Flutter `ApiClient` sets those two request headers from the
`SessionController`, and on a `401` it transparently calls `/auth/refresh` and
replays the request once (see [Chapter 11](11-frontend-architecture.md)).

---

Previous: [Chapter 2 — Project Overview](02-project-overview.md) ·
Next: [Chapter 4 — Getting Started](04-getting-started.md)
