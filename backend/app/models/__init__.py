"""Import every model module so SQLModel.metadata is fully populated.

Alembic's env.py imports this package's metadata for autogenerate support,
and tests rely on all tables being registered before migrations run.
"""
from app.models.user import User
from app.models.workspace import Workspace
from app.models.membership import Membership, MembershipRole
from app.models.project import Project
from app.models.task import Task, TaskPriority, TaskStatus
from app.models.comment import Comment
from app.models.label import Label, TaskLabel
from app.models.activity import ActivityLog

__all__ = [
    "User",
    "Workspace",
    "Membership",
    "MembershipRole",
    "Project",
    "Task",
    "TaskStatus",
    "TaskPriority",
    "Comment",
    "Label",
    "TaskLabel",
    "ActivityLog",
]
