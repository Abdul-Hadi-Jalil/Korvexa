"""Shared FastAPI dependencies.

`get_current_workspace` is the one seam Phase 3 rewires: today it always
resolves "the only workspace that exists" (seeding one on first use). Phase 3
swaps its body for "the workspace named by the caller's JWT, provided their
membership checks out" -- every route that depends on it keeps working
unmodified because the return type (a `Workspace`) doesn't change.
"""
from __future__ import annotations

from fastapi import Depends
from sqlmodel import Session, select

from app.db import get_session
from app.models import User, Workspace
from app.seed import seed_if_empty


def get_current_workspace(session: Session = Depends(get_session)) -> Workspace:
    workspace = session.exec(select(Workspace).order_by(Workspace.id)).first()
    if workspace is None:
        workspace = seed_if_empty(session)
    return workspace


def get_current_user(
    session: Session = Depends(get_session),
    workspace: Workspace = Depends(get_current_workspace),
) -> User:
    """The acting user, used to author comments and stamp activity entries.

    Phase 1/2 has no auth, so this is always the seeded workspace owner. Phase
    3 swaps it for "the user the JWT belongs to" -- same return type, so
    comment/activity code keeps working unchanged.
    """
    user = session.get(User, workspace.owner_id)
    if user is None:  # pragma: no cover - workspace always has an owner
        raise RuntimeError("Workspace owner not found")
    return user
