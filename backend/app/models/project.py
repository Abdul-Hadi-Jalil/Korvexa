from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import UniqueConstraint
from sqlmodel import Field, SQLModel


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class Project(SQLModel, table=True):
    __tablename__ = "projects"
    __table_args__ = (UniqueConstraint("workspace_id", "key", name="uq_project_workspace_key"),)

    id: Optional[int] = Field(default=None, primary_key=True)
    workspace_id: int = Field(foreign_key="workspaces.id", nullable=False, index=True)
    name: str = Field(max_length=255)
    key: str = Field(max_length=10, index=True)
    description: Optional[str] = Field(default=None)
    color: Optional[str] = Field(default=None, max_length=20)
    archived: bool = Field(default=False, index=True)
    # Monotonically increasing counter used to mint each new task's
    # human-readable number (`{project.key}-{task.number}`).
    task_counter: int = Field(default=0)
    created_at: datetime = Field(default_factory=_utcnow)
