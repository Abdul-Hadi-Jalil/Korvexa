from __future__ import annotations

from datetime import datetime
from typing import Optional

from sqlmodel import Field, SQLModel


class LabelCreate(SQLModel):
    name: str = Field(min_length=1, max_length=50)
    color: Optional[str] = Field(default=None, max_length=20)


class LabelUpdate(SQLModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=50)
    color: Optional[str] = Field(default=None, max_length=20)


class LabelRead(SQLModel):
    id: int
    workspace_id: int
    name: str
    color: Optional[str] = None
    created_at: datetime


class TaskLabelsSet(SQLModel):
    """Replace the full set of labels on a task with these label ids."""

    label_ids: list[int]
