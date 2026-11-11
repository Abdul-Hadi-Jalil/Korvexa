# 15. Configuration Reference

All backend configuration is environment-driven, parsed by
[`app/core/config.py`](../backend/app/core/config.py) via **pydantic-settings**.
Values come from (in order) real environment variables, then a `.env` file in
`backend/`, then the built-in defaults. The template is
[`backend/.env.example`](../backend/.env.example).

The frontend has one build-time setting, `API_BASE_URL` (see the bottom of this
chapter).

## Backend environment variables

| Variable | Default | Required? | What it controls |
|----------|---------|-----------|------------------|
| `DATABASE_URL` | `sqlite:///./korvexa.db` | No (Yes in prod) | The database. SQLite, `postgresql+psycopg2://…`, or a Supabase URI. The **only** var you must change to switch databases. |
| `ENVIRONMENT` | `development` | No | Free-form environment label (informational). |
| `CORS_ORIGINS` | `["*"]` | No (set in prod) | JSON array of allowed browser origins. Use your web app's origin(s) in production, e.g. `["https://app.example.com"]`. |
| `SECRET_KEY` | `dev-secret-change-me` | **Yes in prod** | HS256 signing key for JWTs. Generate with `openssl rand -hex 32`. Changing it invalidates all existing tokens. |
| `ALGORITHM` | `HS256` | No | JWT signing algorithm. |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | `30` | No | Access-token lifetime. |
| `REFRESH_TOKEN_EXPIRE_MINUTES` | `43200` (30 days) | No | Refresh-token lifetime. |
| `BCRYPT_ROUNDS` | `12` | No | bcrypt work factor. Keep ≥12 in production; the tests set `4` to stay fast. |
| `RATE_LIMIT_AUTH` | `10/minute` | No | slowapi limit string applied to `/auth/register` and `/auth/login`. |
| `SEED_DEMO` | `false` | No | When `true`, the Docker `entrypoint.sh` runs the demo seeder on start. Consumed by the entrypoint, not `Settings`. |

Notes:

- Variable names are **case-insensitive** and map to the `Settings` field names.
- `SettingsConfigDict(extra="ignore")` means unknown env vars are ignored, so
  you can keep operational vars (like `SEED_DEMO` or `PORT`) in the same `.env`
  without errors.
- `Settings.is_sqlite` is derived from `DATABASE_URL` (used to enable the SQLite
  FK pragma and Alembic batch mode) — not a separate variable.

## `DATABASE_URL` recipes

| Target | Value |
|--------|-------|
| Local SQLite (default) | `sqlite:///./korvexa.db` |
| Local Postgres (compose) | `postgresql+psycopg2://korvexa:korvexa@localhost:5432/korvexa` |
| Postgres inside compose network | `postgresql+psycopg2://korvexa:korvexa@db:5432/korvexa` |
| Supabase / managed Postgres | `postgresql+psycopg2://postgres:[PASSWORD]@[HOST]:5432/postgres` |

> Always use the `postgresql+psycopg2://` scheme (not bare `postgresql://`) so
> SQLAlchemy uses the installed psycopg2 driver.

## Runtime settings not in `.env`

A few values are passed at run time rather than through settings:

| Setting | Where | Notes |
|---------|-------|-------|
| `PORT` | `entrypoint.sh` / uvicorn | Container listen port (default 8000). |
| `X-Request-ID` (request header) | per request | If a client sends it, it's honored and echoed; otherwise generated. See [Chapter 5](05-backend-foundation.md#request-context--logging--loggingpy). |
| `X-Workspace-Id` (request header) | per request | Selects the active workspace. See [Chapter 7](07-auth-and-multitenancy.md). |

## Demo-seed identities

Not configuration per se, but useful: when the demo seeder runs
(`python -m app.seed` or `SEED_DEMO=true`), it creates fixed accounts:

| Role | Email | Password |
|------|-------|----------|
| Owner | `demo@korvexa.app` | `demo-password-123` |
| Member | `teammate@korvexa.app` | `demo-password-123` |

These are defined in [`app/seed.py`](../backend/app/seed.py) and are for demos
only — never enable `SEED_DEMO` on a real deployment.

## Test-time overrides

The test suite sets configuration through the environment before importing the
app (see [`tests/conftest.py`](../backend/tests/conftest.py)):

- `BCRYPT_ROUNDS=4` — so password hashing doesn't dominate the run.
- Each test injects its own throwaway `DATABASE_URL` (a temp SQLite file) via
  Alembic's `config.attributes["configured_url"]`, and overrides the
  `get_session` dependency to point at that database.
- The rate limiter is globally disabled and re-enabled only for the rate-limit
  test.

Details in [Chapter 16](16-testing.md).

## Frontend configuration

The Flutter app has a single setting, resolved by
[`config.dart`](../frontend/lib/config.dart):

| Setting | How to set | Default |
|---------|-----------|---------|
| `API_BASE_URL` | `--dart-define=API_BASE_URL=https://api.example.com` at build/run | `http://127.0.0.1:8000` (web/desktop), `http://10.0.2.2:8000` (Android emulator) |

Example:

```bash
flutter run   --dart-define=API_BASE_URL=http://192.168.1.50:8000
flutter build web --release --dart-define=API_BASE_URL=https://api.example.com
```

There are no other frontend env vars; tokens and the active workspace are stored
at runtime via `flutter_secure_storage` (see [Chapter 11](11-frontend-architecture.md)).

---

Previous: [Chapter 14 — API Reference](14-api-reference.md) ·
Next: [Chapter 16 — Testing](16-testing.md)
