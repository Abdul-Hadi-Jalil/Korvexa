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
from app.models import Workspace
from app.seed import seed_if_empty


def get_current_workspace(session: Session = Depends(get_session)) -> Workspace:
    workspace = session.exec(select(Workspace).order_by(Workspace.id)).first()
    if workspace is None:
        workspace = seed_if_empty(session)
    return workspace
