"""Helpers for creating workspaces and resolving membership."""
from __future__ import annotations

from sqlmodel import Session, select

from app.models import Membership, MembershipRole, Workspace


def create_workspace(session: Session, *, name: str, owner: "User", commit: bool = True) -> Workspace:  # noqa: F821
    """Create a workspace owned by `owner`, with the owner's membership."""
    workspace = Workspace(name=name, owner_id=owner.id)
    session.add(workspace)
    session.flush()

    membership = Membership(
        workspace_id=workspace.id, user_id=owner.id, role=MembershipRole.owner.value
    )
    session.add(membership)
    if commit:
        session.commit()
        session.refresh(workspace)
    return workspace


def user_has_workspace(session: Session, user_id: int) -> bool:
    return (
        session.exec(select(Membership.id).where(Membership.user_id == user_id)).first() is not None
    )
