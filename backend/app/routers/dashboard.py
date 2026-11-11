from __future__ import annotations

from datetime import date

from fastapi import APIRouter, Depends
from sqlmodel import Session, func, select

from app.db import get_session
from app.deps import get_current_user, get_current_workspace
from app.models import Project, Task, TaskPriority, TaskStatus, User, Workspace
from app.schemas.dashboard import DashboardStats

router = APIRouter(prefix="/dashboard", tags=["dashboard"])


@router.get("", response_model=DashboardStats)
def dashboard(
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
    workspace: Workspace = Depends(get_current_workspace),
) -> DashboardStats:
    today = date.today()

    projects_active = session.exec(
        select(func.count()).select_from(Project).where(
            Project.workspace_id == workspace.id, Project.archived == False  # noqa: E712
        )
    ).one()
    projects_archived = session.exec(
        select(func.count()).select_from(Project).where(
            Project.workspace_id == workspace.id, Project.archived == True  # noqa: E712
        )
    ).one()

    # All task stats are over tasks in the workspace's *active* projects.
    active_project_ids = select(Project.id).where(
        Project.workspace_id == workspace.id, Project.archived == False  # noqa: E712
    )
    open_ = Task.status != TaskStatus.done.value
    overdue = (Task.due_date.is_not(None), Task.due_date < today)

    def count(*conditions) -> int:
        return session.exec(
            select(func.count())
            .select_from(Task)
            .where(Task.project_id.in_(active_project_ids), *conditions)
        ).one()

    return DashboardStats(
        projects_active=projects_active,
        projects_archived=projects_archived,
        tasks_total=count(),
        tasks_todo=count(Task.status == TaskStatus.todo.value),
        tasks_in_progress=count(Task.status == TaskStatus.in_progress.value),
        tasks_done=count(Task.status == TaskStatus.done.value),
        tasks_overdue=count(open_, *overdue),
        assigned_to_me_open=count(open_, Task.assignee_id == user.id),
        assigned_to_me_overdue=count(open_, Task.assignee_id == user.id, *overdue),
        priority_high=count(open_, Task.priority == TaskPriority.high.value),
        priority_medium=count(open_, Task.priority == TaskPriority.medium.value),
        priority_low=count(open_, Task.priority == TaskPriority.low.value),
    )
