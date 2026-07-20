from __future__ import annotations

from logging.config import fileConfig

from alembic import context
from sqlalchemy import engine_from_config, pool
from sqlmodel import SQLModel

# Make sure every model is registered on SQLModel.metadata before Alembic
# looks at it (needed for --autogenerate; harmless otherwise).
from app.core.config import get_settings
import app.models  # noqa: F401

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = SQLModel.metadata

# Normally the DB URL comes from application settings (env vars / .env), so
# there is exactly one place that decides which database we talk to. Tests
# instead pass an explicit URL via `config.attributes["configured_url"]` so
# each test run gets its own throwaway SQLite file without touching env vars.
_url = config.attributes.get("configured_url") or get_settings().database_url
config.set_main_option("sqlalchemy.url", _url)


def run_migrations_offline() -> None:
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        render_as_batch=url.startswith("sqlite"),
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            # SQLite can't ALTER TABLE the normal way; batch mode emulates it
            # by rebuilding the table. Postgres ignores this and behaves the
            # same as always. This is what keeps one migration script valid
            # on both databases.
            render_as_batch=connection.engine.url.get_backend_name() == "sqlite",
        )

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
