from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

from sqlmodel import Field, SQLModel


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class ActivityLog(SQLModel, table=True):
    """Append-only audit trail of task mutations (created, status change,
    field edits). Written on the same transaction as the mutation and exposed
    read-only via GET /tasks/{id}/activity.
    """

    __tablename__ = "activity_log"

    id: Optional[int] = Field(default=None, primary_key=True)
    task_id: int = Field(foreign_key="tasks.id", nullable=False, index=True)
    # Nullable because Phase 1/2 has no real auth; Phase 3 always sets it.
    actor_id: Optional[int] = Field(default=None, foreign_key="users.id")
    action: str = Field(max_length=50)
    field: Optional[str] = Field(default=None, max_length=50)
    old_value: Optional[str] = Field(default=None)
    new_value: Optional[str] = Field(default=None)
    created_at: datetime = Field(default_factory=_utcnow)
