"""Helpers for writing task activity-log entries.

Callers add entries to the session but do NOT commit here -- the entry is
committed atomically with the mutation that produced it, so we never end up
with an activity record for a change that got rolled back.
"""
from __future__ import annotations

from typing import Optional

from sqlmodel import Session

from app.models import ActivityLog


def record_activity(
    session: Session,
    *,
    task_id: int,
    action: str,
    field: Optional[str] = None,
    old_value: Optional[object] = None,
    new_value: Optional[object] = None,
    actor_id: Optional[int] = None,
) -> ActivityLog:
    entry = ActivityLog(
        task_id=task_id,
        actor_id=actor_id,
        action=action,
        field=field,
        old_value=None if old_value is None else str(old_value),
        new_value=None if new_value is None else str(new_value),
    )
    session.add(entry)
    return entry
