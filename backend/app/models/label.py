from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import UniqueConstraint
from sqlmodel import Field, SQLModel


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class Label(SQLModel, table=True):
    __tablename__ = "labels"
    __table_args__ = (UniqueConstraint("workspace_id", "name", name="uq_label_workspace_name"),)

    id: Optional[int] = Field(default=None, primary_key=True)
    workspace_id: int = Field(foreign_key="workspaces.id", nullable=False, index=True)
    name: str = Field(max_length=50)
    color: Optional[str] = Field(default=None, max_length=20)
    created_at: datetime = Field(default_factory=_utcnow)


class TaskLabel(SQLModel, table=True):
    """Many-to-many join between tasks and labels."""

    __tablename__ = "task_labels"

    task_id: int = Field(foreign_key="tasks.id", primary_key=True)
    label_id: int = Field(foreign_key="labels.id", primary_key=True)
