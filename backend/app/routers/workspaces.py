from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select

from app.db import get_session
from app.deps import get_current_user
from app.models import Membership, MembershipRole, User, Workspace
from app.schemas.workspace import (
    InviteRequest,
    MemberRead,
    RoleUpdate,
    WorkspaceCreate,
    WorkspaceRead,
)
from app.services.workspaces import create_workspace

router = APIRouter(prefix="/workspaces", tags=["workspaces"])

_VALID_ROLES = {MembershipRole.owner.value, MembershipRole.member.value}


def _membership_or_404(session: Session, user: User, workspace_id: int) -> Membership:
    membership = session.exec(
        select(Membership).where(
            Membership.user_id == user.id, Membership.workspace_id == workspace_id
        )
    ).first()
    if membership is None:
        raise HTTPException(status_code=404, detail="Workspace not found")
    return membership


def _require_owner(session: Session, user: User, workspace_id: int) -> Membership:
    membership = _membership_or_404(session, user, workspace_id)
    if membership.role != MembershipRole.owner.value:
        raise HTTPException(status_code=403, detail="Requires workspace owner role")
    return membership


@router.get("", response_model=list[WorkspaceRead])
def list_workspaces(
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
) -> list[WorkspaceRead]:
    rows = session.exec(
        select(Workspace, Membership.role)
        .join(Membership, Membership.workspace_id == Workspace.id)
        .where(Membership.user_id == user.id)
        .order_by(Workspace.id)
    ).all()
    return [
        WorkspaceRead(
            id=ws.id, name=ws.name, owner_id=ws.owner_id, created_at=ws.created_at, role=role
        )
        for ws, role in rows
    ]


@router.post("", response_model=WorkspaceRead, status_code=201)
def create(
    payload: WorkspaceCreate,
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
) -> WorkspaceRead:
    ws = create_workspace(session, name=payload.name, owner=user)
    return WorkspaceRead(
        id=ws.id, name=ws.name, owner_id=ws.owner_id, created_at=ws.created_at,
        role=MembershipRole.owner.value,
    )


@router.get("/{workspace_id}/members", response_model=list[MemberRead])
def list_members(
    workspace_id: int,
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
) -> list[MemberRead]:
    _membership_or_404(session, user, workspace_id)
    rows = session.exec(
        select(Membership, User)
        .join(User, User.id == Membership.user_id)
        .where(Membership.workspace_id == workspace_id)
        .order_by(Membership.id)
    ).all()
    return [
        MemberRead(
            user_id=member.id,
            email=member.email,
            name=member.name,
            role=membership.role,
            membership_id=membership.id,
        )
        for membership, member in rows
    ]


@router.post("/{workspace_id}/invite", response_model=MemberRead, status_code=201)
def invite(
    workspace_id: int,
    payload: InviteRequest,
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
) -> MemberRead:
    _require_owner(session, user, workspace_id)
    if payload.role not in _VALID_ROLES:
        raise HTTPException(status_code=422, detail="Invalid role")

    invited = session.exec(select(User).where(User.email == payload.email)).first()
    if invited is None:
        # Placeholder account (no password) -- claimed when they register.
        invited = User(email=payload.email, name=payload.email.split("@")[0])
        session.add(invited)
        session.flush()

    existing = session.exec(
        select(Membership).where(
            Membership.workspace_id == workspace_id, Membership.user_id == invited.id
        )
    ).first()
    if existing is not None:
        raise HTTPException(status_code=409, detail="User is already a member")

    membership = Membership(workspace_id=workspace_id, user_id=invited.id, role=payload.role)
    session.add(membership)
    session.commit()
    session.refresh(membership)
    return MemberRead(
        user_id=invited.id,
        email=invited.email,
        name=invited.name,
        role=membership.role,
        membership_id=membership.id,
    )


@router.patch("/{workspace_id}/members/{member_user_id}", response_model=MemberRead)
def update_role(
    workspace_id: int,
    member_user_id: int,
    payload: RoleUpdate,
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
) -> MemberRead:
    _require_owner(session, user, workspace_id)
    if payload.role not in _VALID_ROLES:
        raise HTTPException(status_code=422, detail="Invalid role")

    membership = session.exec(
        select(Membership).where(
            Membership.workspace_id == workspace_id, Membership.user_id == member_user_id
        )
    ).first()
    if membership is None:
        raise HTTPException(status_code=404, detail="Member not found")

    membership.role = payload.role
    session.add(membership)
    session.commit()
    session.refresh(membership)
    member = session.get(User, member_user_id)
    return MemberRead(
        user_id=member.id, email=member.email, name=member.name,
        role=membership.role, membership_id=membership.id,
    )


@router.delete("/{workspace_id}/members/{member_user_id}", status_code=204)
def remove_member(
    workspace_id: int,
    member_user_id: int,
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
) -> None:
    owner_membership = _require_owner(session, user, workspace_id)
    if member_user_id == user.id:
        raise HTTPException(status_code=400, detail="Owners cannot remove themselves")

    membership = session.exec(
        select(Membership).where(
            Membership.workspace_id == workspace_id, Membership.user_id == member_user_id
        )
    ).first()
    if membership is None:
        raise HTTPException(status_code=404, detail="Member not found")
    _ = owner_membership
    session.delete(membership)
    session.commit()
