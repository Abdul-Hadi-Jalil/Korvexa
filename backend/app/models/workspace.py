from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

from sqlmodel import Field, SQLModel


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class Workspace(SQLModel, table=True):
    __tablename__ = "workspaces"

    id: Optional[int] = Field(default=None, primary_key=True)
    name: str = Field(max_length=255)
    owner_id: int = Field(foreign_key="users.id", nullable=False)
    created_at: datetime = Field(default_factory=_utcnow)
