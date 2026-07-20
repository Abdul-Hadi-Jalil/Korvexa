from __future__ import annotations

from datetime import datetime
from typing import Optional

from sqlmodel import SQLModel


class ActivityRead(SQLModel):
    id: int
    task_id: int
    actor_id: Optional[int] = None
    action: str
    field: Optional[str] = None
    old_value: Optional[str] = None
    new_value: Optional[str] = None
    created_at: datetime
