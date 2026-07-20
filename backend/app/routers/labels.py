from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select

from app.db import get_session
from app.deps import get_current_workspace
from app.models import Label, Workspace
from app.schemas.label import LabelCreate, LabelRead, LabelUpdate

router = APIRouter(prefix="/labels", tags=["labels"])


def get_label_or_404(session: Session, workspace: Workspace, label_id: int) -> Label:
    label = session.get(Label, label_id)
    if label is None or label.workspace_id != workspace.id:
        raise HTTPException(status_code=404, detail="Label not found")
    return label


@router.get("", response_model=list[LabelRead])
def list_labels(
    session: Session = Depends(get_session),
    workspace: Workspace = Depends(get_current_workspace),
) -> list[Label]:
    return session.exec(
        select(Label).where(Label.workspace_id == workspace.id).order_by(Label.name)
    ).all()


@router.post("", response_model=LabelRead, status_code=201)
def create_label(
    payload: LabelCreate,
    session: Session = Depends(get_session),
    workspace: Workspace = Depends(get_current_workspace),
) -> Label:
    name = payload.name.strip()
    existing = session.exec(
        select(Label).where(Label.workspace_id == workspace.id, Label.name == name)
    ).first()
    if existing is not None:
        raise HTTPException(status_code=409, detail=f"Label '{name}' already exists")

    label = Label(workspace_id=workspace.id, name=name, color=payload.color)
    session.add(label)
    session.commit()
    session.refresh(label)
    return label


@router.patch("/{label_id}", response_model=LabelRead)
def update_label(
    label_id: int,
    payload: LabelUpdate,
    session: Session = Depends(get_session),
    workspace: Workspace = Depends(get_current_workspace),
) -> Label:
    label = get_label_or_404(session, workspace, label_id)
    data = payload.model_dump(exclude_unset=True)

    if "name" in data:
        new_name = data["name"].strip()
        clash = session.exec(
            select(Label).where(
                Label.workspace_id == workspace.id, Label.name == new_name, Label.id != label.id
            )
        ).first()
        if clash is not None:
            raise HTTPException(status_code=409, detail=f"Label '{new_name}' already exists")
        data["name"] = new_name

    for field, value in data.items():
        setattr(label, field, value)
    session.add(label)
    session.commit()
    session.refresh(label)
    return label


@router.delete("/{label_id}", status_code=204)
def delete_label(
    label_id: int,
    session: Session = Depends(get_session),
    workspace: Workspace = Depends(get_current_workspace),
) -> None:
    label = get_label_or_404(session, workspace, label_id)
    session.delete(label)
    session.commit()
