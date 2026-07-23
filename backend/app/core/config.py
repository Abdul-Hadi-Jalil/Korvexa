"""Application configuration.

All settings are read from environment variables / a local `.env` file via
pydantic-settings. Swapping `DATABASE_URL` is the only change needed to move
between local SQLite, a docker-compose Postgres, or a hosted Supabase Postgres
instance -- no code changes required.
"""
from __future__ import annotations

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    environment: str = "development"

    # Database: works unchanged for sqlite:///, postgresql+psycopg2://, or a
    # Supabase postgres connection string using the same driver prefix.
    database_url: str = "sqlite:///./korvexa.db"

    # CORS
    cors_origins: list[str] = ["*"]

    # Auth (Phase 3)
    secret_key: str = "dev-secret-change-me"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    refresh_token_expire_minutes: int = 60 * 24 * 30
    # bcrypt work factor; keep at 12+ in prod. Tests lower it (via env) so the
    # suite isn't dominated by password hashing.
    bcrypt_rounds: int = 12

    # Rate limiting (auth endpoints; slowapi syntax).
    rate_limit_auth: str = "10/minute"

    @property
    def is_sqlite(self) -> bool:
        return self.database_url.startswith("sqlite")


@lru_cache
def get_settings() -> Settings:
    return Settings()
