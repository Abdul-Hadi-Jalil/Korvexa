from __future__ import annotations

from datetime import date, datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlmodel import Session, func, or_, select

from app.db import get_session
from app.deps import get_current_user, get_current_workspace
from app.models import Label, Membership, Project, Task, TaskLabel, TaskStatus, User, Workspace
from app.routers.projects import get_project_or_404
from app.schemas.pagination import Page
from app.schemas.task import TaskCreate, TaskRead, TaskReorder, TaskUpdate
from app.services.activity import record_activity
from app.services.notifications import notify_assignment
from app.services.serialization import task_to_read, tasks_to_reads
from app.services.task_labels import set_task_labels
from app.utils.position import next_position, position_between

router = APIRouter(tags=["tasks"])

# Fields whose edits are recorded in the activity log.
_TRACKED_FIELDS = ("title", "description", "priority", "assignee_id", "due_date")


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def get_task_or_404(session: Session, workspace: Workspace, task_id: int) -> tuple[Task, Project]:
    task = session.get(Task, task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    project = session.get(Project, task.project_id)
    if project is None or project.workspace_id != workspace.id:
        raise HTTPException(status_code=404, detail="Task not found")
    return task, project


def _serialize(session: Session, task: Task, project: Project) -> TaskRead:
    return tasks_to_reads(session, [task], project)[0]


def _validate_assignee(session: Session, workspace: Workspace, assignee_id: Optional[int]) -> None:
    """An assignee must be a member of the task's workspace (tenant safety)."""
    if assignee_id is None:
        return
    membership = session.exec(
        select(Membership).where(
            Membership.workspace_id == workspace.id, Membership.user_id == assignee_id
        )
    ).first()
    if membership is None:
        raise HTTPException(status_code=400, detail="Assignee is not a member of this workspace")


@router.get("/projects/{project_id}/tasks", response_model=Page[TaskRead])
def list_tasks(
    project_id: int,
    q: Optional[str] = Query(default=None, description="Search title/description"),
    status: Optional[TaskStatus] = None,
    priority: Optional[str] = None,
    label_id: Optional[int] = None,
    due: Optional[str] = Query(default=None, description="overdue|today|week"),
    limit: int = 50,
    offset: int = 0,
    session: Session = Depends(get_session),
    workspace: Workspace = Depends(get_current_workspace),
) -> Page[TaskRead]:
    project = get_project_or_404(session, workspace, project_id)
    limit = max(1, min(limit, 200))
    offset = max(0, offset)

    query = select(Task).where(Task.project_id == project.id)
    query = _apply_task_filters(query, q, status, priority, label_id, due)

    total = session.exec(
        select(func.count()).select_from(query.order_by(None).subquery())
    ).one()
    tasks = session.exec(
        query.order_by(Task.status, Task.position).limit(limit).offset(offset)
    ).all()
    items = tasks_to_reads(session, tasks, project)
    return Page[TaskRead](items=items, total=total, limit=limit, offset=offset)


@router.get("/projects/{project_id}/board", response_model=dict[str, list[TaskRead]])
def get_board(
    project_id: int,
    q: Optional[str] = None,
    priority: Optional[str] = None,
    label_id: Optional[int] = None,
    due: Optional[str] = None,
    session: Session = Depends(get_session),
    workspace: Workspace = Depends(get_current_workspace),
) -> dict[str, list[TaskRead]]:
    project = get_project_or_404(session, workspace, project_id)
    query = select(Task).where(Task.project_id == project.id)
    query = _apply_task_filters(query, q, None, priority, label_id, due)
    tasks = session.exec(query.order_by(Task.position)).all()

    reads = tasks_to_reads(session, tasks, project)
    board: dict[str, list[TaskRead]] = {status.value: [] for status in TaskStatus}
    for read in reads:
        board[read.status.value].append(read)
    return board


def _apply_task_filters(query, q, status, priority, label_id, due):
    if q:
        like = f"%{q}%"
        query = query.where(or_(Task.title.ilike(like), Task.description.ilike(like)))
    if status is not None:
        query = query.where(Task.status == status.value)
    if priority is not None:
        query = query.where(Task.priority == priority)
    if label_id is not None:
        query = query.where(
            Task.id.in_(select(TaskLabel.task_id).where(TaskLabel.label_id == label_id))
        )
    if due:
        today = date.today()
        if due == "overdue":
            query = query.where(Task.due_date.is_not(None), Task.due_date < today)
        elif due == "today":
            query = query.where(Task.due_date.is_not(None), Task.due_date <= today)
        elif due == "week":
            from datetime import timedelta

            query = query.where(Task.due_date.is_not(None), Task.due_date <= today + timedelta(days=7))
    return query


@router.post("/projects/{project_id}/tasks", response_model=TaskRead, status_code=201)
def create_task(
    project_id: int,
    payload: TaskCreate,
    session: Session = Depends(get_session),
    workspace: Workspace = Depends(get_current_workspace),
    user: User = Depends(get_current_user),
) -> TaskRead:
    project = get_project_or_404(session, workspace, project_id)
    _validate_assignee(session, workspace, payload.assignee_id)

    project.task_counter += 1
    number = project.task_counter

    max_position = session.exec(
        select(func.max(Task.position)).where(
            Task.project_id == project.id, Task.status == payload.status.value
        )
    ).one()

    task = Task(
        project_id=project.id,
        number=number,
        title=payload.title,
        description=payload.description,
        status=payload.status.value,
        priority=payload.priority.value,
        assignee_id=payload.assignee_id,
        due_date=payload.due_date,
        position=next_position(max_position),
    )
    session.add(project)
    session.add(task)
    session.flush()  # assign task.id before labels/activity reference it

    if payload.label_ids:
        set_task_labels(session, workspace, task.id, payload.label_ids)

    record_activity(session, task_id=task.id, action="created", actor_id=user.id)
    if payload.assignee_id is not None:
        notify_assignment(
            session,
            workspace_id=workspace.id,
            task_id=task.id,
            task_title=task.title,
            assignee_id=payload.assignee_id,
            actor=user,
        )

    session.commit()
    session.refresh(task)
    return _serialize(session, task, project)


@router.get("/tasks/{task_id}", response_model=TaskRead)
def get_task(
    task_id: int,
    session: Session = Depends(get_session),
    workspace: Workspace = Depends(get_current_workspace),
) -> TaskRead:
    task, project = get_task_or_404(session, workspace, task_id)
    return _serialize(session, task, project)


@router.patch("/tasks/{task_id}", response_model=TaskRead)
def update_task(
    task_id: int,
    payload: TaskUpdate,
    session: Session = Depends(get_session),
    workspace: Workspace = Depends(get_current_workspace),
    user: User = Depends(get_current_user),
) -> TaskRead:
    task, project = get_task_or_404(session, workspace, task_id)
    data = payload.model_dump(exclude_unset=True)

    if "assignee_id" in data:
        _validate_assignee(session, workspace, data["assignee_id"])

    if "status" in data:
        new_status = data.pop("status").value
        if new_status != task.status:
            record_activity(
                session,
                task_id=task.id,
                action="status_changed",
                field="status",
                old_value=task.status,
                new_value=new_status,
                actor_id=user.id,
            )
            if "position" not in data:
                # Moving to a different column with no explicit position:
                # append to the end of the target column.
                max_position = session.exec(
                    select(func.max(Task.position)).where(
                        Task.project_id == task.project_id, Task.status == new_status
                    )
                ).one()
                task.position = next_position(max_position)
        task.status = new_status

    if "priority" in data:
        data["priority"] = data["priority"].value

    if "position" in data:
        task.position = data.pop("position")

    assignee_changed_to: Optional[int] = None
    for field, value in data.items():
        old = getattr(task, field)
        if old != value and field in _TRACKED_FIELDS:
            record_activity(
                session,
                task_id=task.id,
                action="updated",
                field=field,
                old_value=old,
                new_value=value,
                actor_id=user.id,
            )
            if field == "assignee_id" and value is not None:
                assignee_changed_to = value
        setattr(task, field, value)

    if assignee_changed_to is not None:
        notify_assignment(
            session,
            workspace_id=workspace.id,
            task_id=task.id,
            task_title=task.title,
            assignee_id=assignee_changed_to,
            actor=user,
        )

    task.updated_at = _utcnow()
    session.add(task)
    session.commit()
    session.refresh(task)
    return _serialize(session, task, project)


@router.post("/tasks/{task_id}/reorder", response_model=TaskRead)
def reorder_task(
    task_id: int,
    payload: TaskReorder,
    session: Session = Depends(get_session),
    workspace: Workspace = Depends(get_current_workspace),
) -> TaskRead:
    """Reorder within the current column. Writes only the moved task's row."""
    task, project = get_task_or_404(session, workspace, task_id)

    if payload.position is not None:
        task.position = payload.position
    else:
        # before_id = the task the moved card should sit immediately BEFORE
        # (its new successor); after_id = the card it should sit immediately
        # AFTER (its new predecessor). position_between(predecessor, successor).
        predecessor = _sibling_position(session, task, payload.after_id, workspace)
        successor = _sibling_position(session, task, payload.before_id, workspace)
        task.position = position_between(predecessor, successor)

    task.updated_at = _utcnow()
    session.add(task)
    session.commit()
    session.refresh(task)
    return _serialize(session, task, project)


def _sibling_position(
    session: Session, task: Task, sibling_id: Optional[int], workspace: Workspace
) -> Optional[float]:
    if sibling_id is None:
        return None
    sibling, _project = get_task_or_404(session, workspace, sibling_id)
    if sibling.project_id != task.project_id:
        raise HTTPException(status_code=400, detail="Sibling task is in a different project")
    return sibling.position


@router.put("/tasks/{task_id}/labels", response_model=TaskRead)
def set_labels(
    task_id: int,
    label_ids: list[int],
    session: Session = Depends(get_session),
    workspace: Workspace = Depends(get_current_workspace),
) -> TaskRead:
    task, project = get_task_or_404(session, workspace, task_id)
    set_task_labels(session, workspace, task.id, label_ids)
    session.commit()
    session.refresh(task)
    return _serialize(session, task, project)


@router.delete("/tasks/{task_id}", status_code=204)
def delete_task(
    task_id: int,
    session: Session = Depends(get_session),
    workspace: Workspace = Depends(get_current_workspace),
) -> None:
    task, _project = get_task_or_404(session, workspace, task_id)
    session.delete(task)
    session.commit()
