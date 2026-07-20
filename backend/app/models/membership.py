from __future__ import annotations

import enum
from datetime import datetime, timezone
from typing import Optional

from sqlmodel import Field, SQLModel
from sqlalchemy import UniqueConstraint


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class MembershipRole(str, enum.Enum):
    owner = "owner"
    member = "member"


class Membership(SQLModel, table=True):
    """The "team later" hook: Phase 1 always has exactly one row per
    workspace (the seeded owner). Phase 3 turns this into real multi-user
    membership with invites and role checks.
    """

    __tablename__ = "memberships"
    __table_args__ = (UniqueConstraint("workspace_id", "user_id", name="uq_membership_workspace_user"),)

    id: Optional[int] = Field(default=None, primary_key=True)
    workspace_id: int = Field(foreign_key="workspaces.id", nullable=False, index=True)
    user_id: int = Field(foreign_key="users.id", nullable=False, index=True)
    role: str = Field(default=MembershipRole.member.value, max_length=20)
    created_at: datetime = Field(default_factory=_utcnow)
