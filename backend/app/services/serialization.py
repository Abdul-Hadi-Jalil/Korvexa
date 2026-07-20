"""Helpers that turn ORM rows into read schemas, including their labels.

Loading labels in a single batched query (rather than per-task) keeps board
and list endpoints from issuing N+1 queries.
"""
from __future__ import annotations

from sqlmodel import Session, select

from app.models import Label, Project, Task, TaskLabel
from app.schemas.label import LabelRead
from app.schemas.task import TaskRead, TaskWithProjectRead


def labels_for_tasks(session: Session, task_ids: list[int]) -> dict[int, list[LabelRead]]:
    if not task_ids:
        return {}
    rows = session.exec(
        select(TaskLabel.task_id, Label)
        .join(Label, TaskLabel.label_id == Label.id)
        .where(TaskLabel.task_id.in_(task_ids))
        .order_by(Label.name)
    ).all()
    result: dict[int, list[LabelRead]] = {}
    for task_id, label in rows:
        result.setdefault(task_id, []).append(LabelRead.model_validate(label, from_attributes=True))
    return result


def task_to_read(task: Task, project: Project, labels: list[LabelRead] | None = None) -> TaskRead:
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
        labels=labels or [],
    )


def tasks_to_reads(session: Session, tasks: list[Task], project: Project) -> list[TaskRead]:
    label_map = labels_for_tasks(session, [t.id for t in tasks])
    return [task_to_read(t, project, label_map.get(t.id, [])) for t in tasks]


def task_with_project_to_read(
    task: Task, project: Project, labels: list[LabelRead] | None = None
) -> TaskWithProjectRead:
    base = task_to_read(task, project, labels)
    return TaskWithProjectRead(
        **base.model_dump(),
        project_name=project.name,
        project_key=project.key,
    )
