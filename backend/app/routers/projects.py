from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, func, select

from app.db import get_session
from app.deps import get_current_workspace, require_owner
from app.models import Membership, Project, Task, TaskStatus, Workspace
from app.schemas.project import ProjectCreate, ProjectRead, ProjectUpdate
from app.utils.keygen import derive_project_key, unique_project_key

router = APIRouter(prefix="/projects", tags=["projects"])


def get_project_or_404(session: Session, workspace: Workspace, project_id: int) -> Project:
    project = session.get(Project, project_id)
    if project is None or project.workspace_id != workspace.id:
        # Same 404 whether the project doesn't exist at all or belongs to a
        # different workspace -- callers can never distinguish "not found"
        # from "not yours".
        raise HTTPException(status_code=404, detail="Project not found")
    return project


def project_to_read(session: Session, project: Project) -> ProjectRead:
    total = session.exec(select(func.count()).select_from(Task).where(Task.project_id == project.id)).one()
    open_ = session.exec(
        select(func.count())
        .select_from(Task)
        .where(Task.project_id == project.id, Task.status != TaskStatus.done.value)
    ).one()
    return ProjectRead(
        id=project.id,
        workspace_id=project.workspace_id,
        name=project.name,
        key=project.key,
        description=project.description,
        color=project.color,
        archived=project.archived,
        created_at=project.created_at,
        open_tasks=open_,
        total_tasks=total,
    )


@router.get("", response_model=list[ProjectRead])
def list_projects(
    include_archived: bool = False,
    session: Session = Depends(get_session),
    workspace: Workspace = Depends(get_current_workspace),
) -> list[ProjectRead]:
    query = select(Project).where(Project.workspace_id == workspace.id)
    if not include_archived:
        query = query.where(Project.archived == False)  # noqa: E712
    query = query.order_by(Project.created_at)
    projects = session.exec(query).all()
    return [project_to_read(session, p) for p in projects]


@router.post("", response_model=ProjectRead, status_code=201)
def create_project(
    payload: ProjectCreate,
    session: Session = Depends(get_session),
    workspace: Workspace = Depends(get_current_workspace),
) -> ProjectRead:
    existing_keys = set(
        session.exec(select(Project.key).where(Project.workspace_id == workspace.id)).all()
    )

    if payload.key:
        key = payload.key.strip().upper()
        if key in existing_keys:
            raise HTTPException(status_code=409, detail=f"Project key '{key}' already exists")
    else:
        key = unique_project_key(derive_project_key(payload.name), existing_keys)

    project = Project(
        workspace_id=workspace.id,
        name=payload.name,
        key=key,
        description=payload.description,
        color=payload.color,
    )
    session.add(project)
    session.commit()
    session.refresh(project)
    return project_to_read(session, project)


@router.get("/{project_id}", response_model=ProjectRead)
def get_project(
    project_id: int,
    session: Session = Depends(get_session),
    workspace: Workspace = Depends(get_current_workspace),
) -> ProjectRead:
    project = get_project_or_404(session, workspace, project_id)
    return project_to_read(session, project)


@router.patch("/{project_id}", response_model=ProjectRead)
def update_project(
    project_id: int,
    payload: ProjectUpdate,
    session: Session = Depends(get_session),
    workspace: Workspace = Depends(get_current_workspace),
) -> ProjectRead:
    project = get_project_or_404(session, workspace, project_id)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(project, field, value)
    session.add(project)
    session.commit()
    session.refresh(project)
    return project_to_read(session, project)


@router.post("/{project_id}/archive", response_model=ProjectRead)
def archive_project(
    project_id: int,
    session: Session = Depends(get_session),
    workspace: Workspace = Depends(get_current_workspace),
) -> ProjectRead:
    project = get_project_or_404(session, workspace, project_id)
    project.archived = True
    session.add(project)
    session.commit()
    session.refresh(project)
    return project_to_read(session, project)


@router.post("/{project_id}/unarchive", response_model=ProjectRead)
def unarchive_project(
    project_id: int,
    session: Session = Depends(get_session),
    workspace: Workspace = Depends(get_current_workspace),
) -> ProjectRead:
    project = get_project_or_404(session, workspace, project_id)
    project.archived = False
    session.add(project)
    session.commit()
    session.refresh(project)
    return project_to_read(session, project)


@router.delete("/{project_id}", status_code=204)
def delete_project(
    project_id: int,
    session: Session = Depends(get_session),
    workspace: Workspace = Depends(get_current_workspace),
    _owner: Membership = Depends(require_owner),
) -> None:
    # Owner-only (require_owner 403s for members).
    project = get_project_or_404(session, workspace, project_id)
    session.delete(project)
    session.commit()
