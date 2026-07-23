"""Shared pytest fixtures.

Every test gets its own throwaway SQLite database file, built by actually
running `alembic upgrade head` against it -- migrations are the source of
truth for the schema, so if a migration is broken, tests fail loudly instead
of silently working around it with `metadata.create_all`.

Auth note (Phase 3): the default `client` fixture is authenticated -- it
registers a user, creates their personal workspace, and sets default
`Authorization` + `X-Workspace-Id` headers. This is what lets all the Phase
1/2 tests keep hitting the same endpoints unchanged now that auth is real.
Use `raw_client` for auth-endpoint and 401 tests, and `register_client` to
build additional authenticated users (multi-tenant / role tests).
"""
from __future__ import annotations

import os

# Lower the bcrypt work factor for the test suite (set before the app/settings
# are imported so it takes effect). Never used in production paths.
os.environ.setdefault("BCRYPT_ROUNDS", "4")

import uuid  # noqa: E402
from collections.abc import Iterator  # noqa: E402
from pathlib import Path  # noqa: E402

import pytest  # noqa: E402
from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient
from sqlalchemy import event
from sqlmodel import Session, create_engine

BACKEND_DIR = Path(__file__).resolve().parent.parent


@pytest.fixture()
def test_engine(tmp_path):
    db_path = tmp_path / f"test_{uuid.uuid4().hex}.db"
    db_url = f"sqlite:///{db_path}"

    cfg = Config(str(BACKEND_DIR / "alembic.ini"))
    cfg.set_main_option("script_location", str(BACKEND_DIR / "alembic"))
    cfg.attributes["configured_url"] = db_url
    command.upgrade(cfg, "head")

    engine = create_engine(db_url, connect_args={"check_same_thread": False})

    @event.listens_for(engine, "connect")
    def _fk_pragma(dbapi_connection, _record) -> None:
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()

    yield engine
    engine.dispose()


@pytest.fixture()
def session(test_engine) -> Iterator[Session]:
    with Session(test_engine) as session:
        yield session


def _make_test_client(test_engine) -> TestClient:
    # Import app lazily so `DATABASE_URL`/settings from the environment never
    # matter for tests -- the app's DB dependency is overridden to always
    # point at this test's isolated engine.
    from app.db import get_session
    from app.main import app

    def _override_get_session() -> Iterator[Session]:
        with Session(test_engine) as session:
            yield session

    app.dependency_overrides[get_session] = _override_get_session
    # Rate limiter would otherwise carry state across tests; disable in tests.
    app.state.limiter.enabled = False
    return TestClient(app)


def register_user(
    client: TestClient, email: str, name: str, password: str = "password123"
) -> dict:
    """Register a user (auth headers not required) and return tokens + their
    default personal workspace id.
    """
    resp = client.post(
        "/auth/register", json={"email": email, "name": name, "password": password}
    )
    assert resp.status_code == 201, resp.text
    tokens = resp.json()
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}
    workspaces = client.get("/workspaces", headers=headers).json()
    return {
        "access_token": tokens["access_token"],
        "refresh_token": tokens["refresh_token"],
        "workspace_id": workspaces[0]["id"],
        "email": email,
        "name": name,
        "headers": {**headers, "X-Workspace-Id": str(workspaces[0]["id"])},
    }


@pytest.fixture()
def raw_client(test_engine) -> Iterator[TestClient]:
    """An unauthenticated client, for exercising auth endpoints and 401s."""
    client = _make_test_client(test_engine)
    with client:
        yield client
    from app.main import app

    app.dependency_overrides.clear()


@pytest.fixture()
def client(test_engine) -> Iterator[TestClient]:
    """Authenticated client for the default owner + their personal workspace.

    The registered context is stashed at `client.auth_context` so tests can
    read the workspace id, tokens, etc. (`auth` is reserved by httpx.)
    """
    client = _make_test_client(test_engine)
    with client:
        ctx = register_user(client, "owner@example.com", "Workspace Owner")
        client.headers.update(ctx["headers"])
        client.auth_context = ctx  # type: ignore[attr-defined]
        yield client
    from app.main import app

    app.dependency_overrides.clear()


@pytest.fixture()
def register_client(test_engine):
    """Factory to register additional users on the SAME database as `client`,
    each returning their own auth context (with ready-to-use headers). Used by
    multi-tenant and role tests.
    """
    created = _make_test_client(test_engine)

    def _factory(email: str, name: str) -> dict:
        return register_user(created, email, name)

    with created:
        yield _factory
    from app.main import app

    app.dependency_overrides.clear()
