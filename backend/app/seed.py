"""First-run seed: one user, one workspace, one owner membership.

Phase 1 has no auth yet, so this is what makes the app usable out of the box.
Called lazily (see `app.deps.get_current_workspace`) rather than at process
startup so it works the same way in production and in tests, regardless of
which engine/session a given request is bound to.
"""
from __future__ import annotations

from sqlmodel import Session, select

from app.core.config import get_settings
from app.models import Membership, MembershipRole, User, Workspace


def seed_if_empty(session: Session) -> Workspace:
    """Create the default user/workspace/membership if none exist yet.

    Returns the workspace either way (existing or newly created), so callers
    can use this as a "get or create" without a second query.
    """
    workspace = session.exec(select(Workspace).order_by(Workspace.id)).first()
    if workspace is not None:
        return workspace

    settings = get_settings()

    user = session.exec(select(User).where(User.email == settings.seed_user_email)).first()
    if user is None:
        user = User(email=settings.seed_user_email, name=settings.seed_user_name)
        session.add(user)
        session.flush()  # populate user.id

    workspace = Workspace(name=settings.seed_workspace_name, owner_id=user.id)
    session.add(workspace)
    session.flush()

    membership = Membership(
        workspace_id=workspace.id,
        user_id=user.id,
        role=MembershipRole.owner.value,
    )
    session.add(membership)
    session.commit()
    session.refresh(workspace)
    return workspace
