from __future__ import annotations

from datetime import date, timedelta
from typing import Literal

from fastapi import APIRouter, Depends
from sqlmodel import Session, select

from app.db import get_session
from app.deps import get_current_workspace
from app.models import Project, Task, TaskStatus, Workspace
from app.schemas.task import TaskWithProjectRead

router = APIRouter(prefix="/me", tags=["me"])

_PRIORITY_RANK = {"high": 0, "medium": 1, "low": 2}


@router.get("/upcoming", response_model=list[TaskWithProjectRead])
def upcoming(
    window: Literal["today", "week", "all"] = "all",
    session: Session = Depends(get_session),
    workspace: Workspace = Depends(get_current_workspace),
) -> list[TaskWithProjectRead]:
    """Open tasks across every project in the workspace.

    Always excludes `done` and always includes overdue tasks, regardless of
    window. `today`/`week` additionally require a due date within that
    horizon; `all` returns every open task, due date or not.
    """
    today = date.today()

    query = (
        select(Task, Project)
        .join(Project, Task.project_id == Project.id)
        .where(Project.workspace_id == workspace.id, Task.status != TaskStatus.done.value)
    )

    if window == "today":
        query = query.where(Task.due_date.is_not(None), Task.due_date <= today)
    elif window == "week":
        query = query.where(Task.due_date.is_not(None), Task.due_date <= today + timedelta(days=7))
    # window == "all": no due-date filter -- every open task.

    rows = session.exec(query).all()

    def sort_key(row: tuple[Task, Project]):
        task, _project = row
        due = task.due_date or date.max
        return (due, _PRIORITY_RANK.get(task.priority, 3))

    rows.sort(key=sort_key)

    return [
        TaskWithProjectRead(
            id=task.id,
            project_id=task.project_id,
            number=task.number,
            key=f"{project.key}-{task.number}",
            title=task.title,
            description=task.description,
            status=task.status,
            priority=task.priority,
            assignee_id=task.assignee_id,
            due_date=task.due_date,
            position=task.position,
            created_at=task.created_at,
            updated_at=task.updated_at,
            project_name=project.name,
            project_key=project.key,
        )
        for task, project in rows
    ]
