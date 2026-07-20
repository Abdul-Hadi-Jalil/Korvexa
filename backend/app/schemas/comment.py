from __future__ import annotations

from datetime import datetime
from typing import Optional

from sqlmodel import Field, SQLModel


class CommentCreate(SQLModel):
    body: str = Field(min_length=1)


class CommentUpdate(SQLModel):
    body: str = Field(min_length=1)


class CommentRead(SQLModel):
    id: int
    task_id: int
    author_id: int
    author_name: Optional[str] = None
    body: str
    created_at: datetime
    updated_at: datetime
