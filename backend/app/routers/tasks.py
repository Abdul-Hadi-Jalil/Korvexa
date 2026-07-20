from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, func, select

from app.db import get_session
from app.deps import get_current_workspace
from app.models import Project, Task, TaskStatus, Workspace
from app.routers.projects import get_project_or_404
from app.schemas.task import TaskCreate, TaskRead, TaskUpdate
from app.utils.position import next_position

router = APIRouter(tags=["tasks"])


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def task_to_read(task: Task, project: Project) -> TaskRead:
    return TaskRead(
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
    )


def get_task_or_404(session: Session, workspace: Workspace, task_id: int) -> tuple[Task, Project]:
    task = session.get(Task, task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    project = session.get(Project, task.project_id)
    if project is None or project.workspace_id != workspace.id:
        raise HTTPException(status_code=404, detail="Task not found")
    return task, project


@router.get("/projects/{project_id}/tasks", response_model=list[TaskRead])
def list_tasks(
    project_id: int,
    session: Session = Depends(get_session),
    workspace: Workspace = Depends(get_current_workspace),
) -> list[TaskRead]:
    project = get_project_or_404(session, workspace, project_id)
    tasks = session.exec(
        select(Task).where(Task.project_id == project.id).order_by(Task.status, Task.position)
    ).all()
    return [task_to_read(t, project) for t in tasks]


@router.get("/projects/{project_id}/board", response_model=dict[str, list[TaskRead]])
def get_board(
    project_id: int,
    session: Session = Depends(get_session),
    workspace: Workspace = Depends(get_current_workspace),
) -> dict[str, list[TaskRead]]:
    project = get_project_or_404(session, workspace, project_id)
    tasks = session.exec(
        select(Task).where(Task.project_id == project.id).order_by(Task.position)
    ).all()
    board: dict[str, list[TaskRead]] = {status.value: [] for status in TaskStatus}
    for task in tasks:
        board[task.status].append(task_to_read(task, project))
    return board


@router.post("/projects/{project_id}/tasks", response_model=TaskRead, status_code=201)
def create_task(
    project_id: int,
    payload: TaskCreate,
    session: Session = Depends(get_session),
    workspace: Workspace = Depends(get_current_workspace),
) -> TaskRead:
    project = get_project_or_404(session, workspace, project_id)

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
    session.commit()
    session.refresh(task)
    return task_to_read(task, project)


@router.get("/tasks/{task_id}", response_model=TaskRead)
def get_task(
    task_id: int,
    session: Session = Depends(get_session),
    workspace: Workspace = Depends(get_current_workspace),
) -> TaskRead:
    task, project = get_task_or_404(session, workspace, task_id)
    return task_to_read(task, project)


@router.patch("/tasks/{task_id}", response_model=TaskRead)
def update_task(
    task_id: int,
    payload: TaskUpdate,
    session: Session = Depends(get_session),
    workspace: Workspace = Depends(get_current_workspace),
) -> TaskRead:
    task, project = get_task_or_404(session, workspace, task_id)
    data = payload.model_dump(exclude_unset=True)

    if "status" in data:
        new_status = data.pop("status").value
        if new_status != task.status and "position" not in data:
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
        task.priority = data.pop("priority").value

    if "position" in data:
        task.position = data.pop("position")

    for field, value in data.items():
        setattr(task, field, value)

    task.updated_at = _utcnow()
    session.add(task)
    session.commit()
    session.refresh(task)
    return task_to_read(task, project)


@router.delete("/tasks/{task_id}", status_code=204)
def delete_task(
    task_id: int,
    session: Session = Depends(get_session),
    workspace: Workspace = Depends(get_current_workspace),
) -> None:
    task, _project = get_task_or_404(session, workspace, task_id)
    session.delete(task)
    session.commit()
