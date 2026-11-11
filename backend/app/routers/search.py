from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlmodel import Session, or_, select

from app.db import get_session
from app.deps import get_current_workspace
from app.models import Project, Task, Workspace
from app.schemas.task import TaskWithProjectRead
from app.services.serialization import labels_for_tasks, task_with_project_to_read

router = APIRouter(prefix="/search", tags=["search"])


@router.get("/tasks", response_model=list[TaskWithProjectRead])
def search_tasks(
    q: str = Query(min_length=1, description="Search text (title/description)"),
    limit: int = 30,
    session: Session = Depends(get_session),
    workspace: Workspace = Depends(get_current_workspace),
) -> list[TaskWithProjectRead]:
    """Workspace-wide task search across all active projects, by title or
    description. Results carry their project name/key and are newest-updated
    first. Scoped to the current workspace -- other tenants' tasks never match.
    """
    text = q.strip()
    if not text:
        return []
    limit = max(1, min(limit, 100))
    like = f"%{text}%"

    rows = session.exec(
        select(Task, Project)
        .join(Project, Task.project_id == Project.id)
        .where(
            Project.workspace_id == workspace.id,
            Project.archived == False,  # noqa: E712
            or_(Task.title.ilike(like), Task.description.ilike(like)),
        )
        .order_by(Task.updated_at.desc())
        .limit(limit)
    ).all()

    label_map = labels_for_tasks(session, [task.id for task, _ in rows])
    return [
        task_with_project_to_read(task, project, label_map.get(task.id, []))
        for task, project in rows
    ]
