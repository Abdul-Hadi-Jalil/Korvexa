"""Validate + assign the set of labels on a task.

Labels are workspace-scoped, so assigning a label that belongs to another
workspace (or doesn't exist) is rejected -- this is part of the multi-tenant
isolation guarantee.
"""
from __future__ import annotations

from fastapi import HTTPException
from sqlmodel import Session, select

from app.models import Label, TaskLabel, Workspace


def set_task_labels(
    session: Session, workspace: Workspace, task_id: int, label_ids: list[int]
) -> None:
    unique_ids = list(dict.fromkeys(label_ids))  # de-dupe, preserve order

    if unique_ids:
        found = session.exec(
            select(Label.id).where(Label.id.in_(unique_ids), Label.workspace_id == workspace.id)
        ).all()
        missing = set(unique_ids) - set(found)
        if missing:
            raise HTTPException(
                status_code=400,
                detail=f"Unknown label id(s) for this workspace: {sorted(missing)}",
            )

    # Replace the full set: clear existing links, then add the requested ones.
    existing_links = session.exec(select(TaskLabel).where(TaskLabel.task_id == task_id)).all()
    for link in existing_links:
        session.delete(link)
    for label_id in unique_ids:
        session.add(TaskLabel(task_id=task_id, label_id=label_id))
