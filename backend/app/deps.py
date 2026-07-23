"""Auth + tenancy dependencies (Phase 3).

This is the seam Phase 1/2 kept simple ("the only workspace that exists").
It now resolves the acting user from a JWT and the active workspace from the
`X-Workspace-Id` header, enforcing that the user is a member. Because the
return types are unchanged (`User`, `Workspace`), every route written in
Phase 1/2 keeps working without modification -- only this file changed.
"""
from __future__ import annotations

from typing import Optional

from fastapi import Depends, Header, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlmodel import Session, select

from app.core.security import ACCESS_TOKEN_TYPE, decode_token
from app.db import get_session
from app.models import Membership, MembershipRole, User, Workspace

# auto_error=False so we can raise our own consistent 401 instead of FastAPI's.
_bearer = HTTPBearer(auto_error=False)


def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(_bearer),
    session: Session = Depends(get_session),
) -> User:
    if credentials is None or not credentials.credentials:
        raise HTTPException(status_code=401, detail="Not authenticated")
    user_id = decode_token(credentials.credentials, expected_type=ACCESS_TOKEN_TYPE)
    if user_id is None:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    user = session.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    return user


def get_current_membership(
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
    x_workspace_id: Optional[int] = Header(default=None),
) -> Membership:
    """Resolve the active workspace membership.

    The client selects a workspace with the `X-Workspace-Id` header (this is
    what the frontend's workspace switcher sets). If omitted, we fall back to
    the user's first workspace so single-workspace clients need no header.
    A user who isn't a member of the requested workspace gets a 404 -- they
    can't even tell it exists.
    """
    if x_workspace_id is not None:
        membership = session.exec(
            select(Membership).where(
                Membership.user_id == user.id, Membership.workspace_id == x_workspace_id
            )
        ).first()
        if membership is None:
            raise HTTPException(status_code=404, detail="Workspace not found")
        return membership

    membership = session.exec(
        select(Membership).where(Membership.user_id == user.id).order_by(Membership.workspace_id)
    ).first()
    if membership is None:
        raise HTTPException(status_code=404, detail="No workspace available")
    return membership


def get_current_workspace(
    membership: Membership = Depends(get_current_membership),
    session: Session = Depends(get_session),
) -> Workspace:
    workspace = session.get(Workspace, membership.workspace_id)
    if workspace is None:  # pragma: no cover - membership implies workspace
        raise HTTPException(status_code=404, detail="Workspace not found")
    return workspace


def require_owner(membership: Membership = Depends(get_current_membership)) -> Membership:
    """Guard for owner-only actions (delete project, manage members)."""
    if membership.role != MembershipRole.owner.value:
        raise HTTPException(status_code=403, detail="Requires workspace owner role")
    return membership
