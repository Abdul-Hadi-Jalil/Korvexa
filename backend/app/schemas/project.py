from __future__ import annotations

from datetime import datetime
from typing import Optional

from sqlmodel import Field, SQLModel


class ProjectCreate(SQLModel):
    name: str = Field(min_length=1, max_length=255)
    key: Optional[str] = Field(default=None, min_length=1, max_length=10)
    description: Optional[str] = None
    color: Optional[str] = Field(default=None, max_length=20)


class ProjectUpdate(SQLModel):
    """Only fields present in the request body are applied (PATCH semantics)."""

    name: Optional[str] = Field(default=None, min_length=1, max_length=255)
    description: Optional[str] = None
    color: Optional[str] = Field(default=None, max_length=20)


class ProjectRead(SQLModel):
    id: int
    workspace_id: int
    name: str
    key: str
    description: Optional[str] = None
    color: Optional[str] = None
    archived: bool
    created_at: datetime
    open_tasks: int
    total_tasks: int
