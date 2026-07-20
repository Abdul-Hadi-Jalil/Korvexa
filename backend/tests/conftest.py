"""Shared pytest fixtures.

Every test gets its own throwaway SQLite database file, built by actually
running `alembic upgrade head` against it -- migrations are the source of
truth for the schema, so if a migration is broken, tests fail loudly instead
of silently working around it with `metadata.create_all`.
"""
from __future__ import annotations

import os
import uuid
from collections.abc import Iterator
from pathlib import Path

import pytest
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


@pytest.fixture()
def client(test_engine) -> Iterator[TestClient]:
    # Import app lazily so `DATABASE_URL`/settings from the environment never
    # matter for tests -- the app's DB dependency is overridden below to
    # always point at this test's isolated engine.
    from app.db import get_session
    from app.main import app

    def _override_get_session() -> Iterator[Session]:
        with Session(test_engine) as session:
            yield session

    app.dependency_overrides[get_session] = _override_get_session
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()
