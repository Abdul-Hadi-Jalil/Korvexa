from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import EmailStr
from sqlmodel import Field, SQLModel


class WorkspaceCreate(SQLModel):
    name: str = Field(min_length=1, max_length=255)


class WorkspaceRead(SQLModel):
    id: int
    name: str
    owner_id: int
    created_at: datetime
    role: str  # the current user's role in this workspace


class MemberRead(SQLModel):
    user_id: int
    email: str
    name: str
    role: str
    membership_id: int


class InviteRequest(SQLModel):
    email: EmailStr
    role: str = "member"


class RoleUpdate(SQLModel):
    role: str


class NotificationRead(SQLModel):
    id: int
    type: str
    task_id: Optional[int] = None
    comment_id: Optional[int] = None
    actor_id: Optional[int] = None
    message: str
    read: bool
    created_at: datetime
