from __future__ import annotations

import enum
from datetime import date, datetime, timezone
from typing import Optional

from sqlalchemy import UniqueConstraint
from sqlmodel import Field, SQLModel


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class TaskStatus(str, enum.Enum):
    todo = "todo"
    in_progress = "in_progress"
    done = "done"


class TaskPriority(str, enum.Enum):
    low = "low"
    medium = "medium"
    high = "high"


class Task(SQLModel, table=True):
    __tablename__ = "tasks"
    __table_args__ = (UniqueConstraint("project_id", "number", name="uq_task_project_number"),)

    id: Optional[int] = Field(default=None, primary_key=True)
    project_id: int = Field(foreign_key="projects.id", nullable=False, index=True)
    # Sequential per project; combined with project.key forms e.g. "ACME-42".
    number: int = Field(nullable=False)
    title: str = Field(max_length=500)
    description: Optional[str] = Field(default=None)
    status: str = Field(default=TaskStatus.todo.value, max_length=20, index=True)
    priority: str = Field(default=TaskPriority.medium.value, max_length=20, index=True)
    assignee_id: Optional[int] = Field(default=None, foreign_key="users.id", index=True)
    due_date: Optional[date] = Field(default=None, index=True)
    # Fractional rank for stable drag-and-drop ordering within a status
    # column -- reordering one card only ever touches its own row.
    position: float = Field(default=0.0)
    created_at: datetime = Field(default_factory=_utcnow)
    updated_at: datetime = Field(default_factory=_utcnow)
