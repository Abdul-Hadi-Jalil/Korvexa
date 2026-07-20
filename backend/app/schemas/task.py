from __future__ import annotations

from datetime import date, datetime
from typing import Optional

from sqlmodel import Field, SQLModel

from app.models.task import TaskPriority, TaskStatus


class TaskCreate(SQLModel):
    title: str = Field(min_length=1, max_length=500)
    description: Optional[str] = None
    status: TaskStatus = TaskStatus.todo
    priority: TaskPriority = TaskPriority.medium
    assignee_id: Optional[int] = None
    due_date: Optional[date] = None


class TaskUpdate(SQLModel):
    """PATCH semantics: only fields present in the request body are applied.

    `position` is only meaningful when moving/reordering a card; if omitted
    on a status change the task is appended to the end of the target column.
    """

    title: Optional[str] = Field(default=None, min_length=1, max_length=500)
    description: Optional[str] = None
    status: Optional[TaskStatus] = None
    priority: Optional[TaskPriority] = None
    assignee_id: Optional[int] = None
    due_date: Optional[date] = None
    position: Optional[float] = None


class TaskRead(SQLModel):
    id: int
    project_id: int
    number: int
    key: str
    title: str
    description: Optional[str] = None
    status: TaskStatus
    priority: TaskPriority
    assignee_id: Optional[int] = None
    due_date: Optional[date] = None
    position: float
    created_at: datetime
    updated_at: datetime


class TaskWithProjectRead(TaskRead):
    project_name: str
    project_key: str
