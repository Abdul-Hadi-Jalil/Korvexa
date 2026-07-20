from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

from sqlmodel import Field, SQLModel


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class User(SQLModel, table=True):
    __tablename__ = "users"

    id: Optional[int] = Field(default=None, primary_key=True)
    email: str = Field(index=True, unique=True, max_length=255)
    name: str = Field(max_length=255)
    # Null until Phase 3 wires up real registration/password auth.
    password_hash: Optional[str] = Field(default=None)
    created_at: datetime = Field(default_factory=_utcnow)
