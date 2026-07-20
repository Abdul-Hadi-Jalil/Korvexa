"""Database engine + session handling.

Uses plain synchronous SQLAlchemy (via SQLModel) so the same code path works
against sqlite:// (dev/test), postgresql+psycopg2:// (docker-compose), and a
Supabase postgres connection string -- only `DATABASE_URL` changes.
"""
from __future__ import annotations

from collections.abc import Iterator

from sqlalchemy import event
from sqlmodel import Session, create_engine

from app.core.config import get_settings

settings = get_settings()

_connect_args = {"check_same_thread": False} if settings.is_sqlite else {}

engine = create_engine(settings.database_url, echo=False, connect_args=_connect_args)

if settings.is_sqlite:
    # SQLite ignores foreign key constraints unless explicitly turned on per
    # connection. Postgres enforces them natively, so this keeps behavior
    # (cascades, FK errors) consistent across both backends.
    @event.listens_for(engine, "connect")
    def _set_sqlite_pragma(dbapi_connection, _connection_record) -> None:
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()


def get_session() -> Iterator[Session]:
    with Session(engine) as session:
        yield session
