from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

from sqlmodel import Field, SQLModel


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class Notification(SQLModel, table=True):
    """In-app notification. Created when a user is assigned a task or
    @mentioned in a comment. Email delivery is stubbed (see services/email.py).
    """

    __tablename__ = "notifications"

    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="users.id", nullable=False, index=True)
    workspace_id: int = Field(foreign_key="workspaces.id", nullable=False, index=True)
    type: str = Field(max_length=30)  # "assigned" | "mention"
    task_id: Optional[int] = Field(default=None, foreign_key="tasks.id")
    comment_id: Optional[int] = Field(default=None, foreign_key="comments.id")
    actor_id: Optional[int] = Field(default=None, foreign_key="users.id")
    message: str
    read: bool = Field(default=False, index=True)
    created_at: datetime = Field(default_factory=_utcnow)
