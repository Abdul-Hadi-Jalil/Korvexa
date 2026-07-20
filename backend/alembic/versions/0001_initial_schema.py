"""initial schema: users, workspaces, memberships, projects, tasks

Revision ID: 0001_initial
Revises:
Create Date: 2026-07-21

"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0001_initial"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("email", sa.String(length=255), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("password_hash", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_users_email", "users", ["email"], unique=True)

    op.create_table(
        "workspaces",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("owner_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )

    op.create_table(
        "memberships",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "workspace_id",
            sa.Integer(),
            sa.ForeignKey("workspaces.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("role", sa.String(length=20), nullable=False, server_default="member"),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("workspace_id", "user_id", name="uq_membership_workspace_user"),
    )
    op.create_index("ix_memberships_workspace_id", "memberships", ["workspace_id"])
    op.create_index("ix_memberships_user_id", "memberships", ["user_id"])

    op.create_table(
        "projects",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "workspace_id",
            sa.Integer(),
            sa.ForeignKey("workspaces.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("key", sa.String(length=10), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("color", sa.String(length=20), nullable=True),
        sa.Column("archived", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("task_counter", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("workspace_id", "key", name="uq_project_workspace_key"),
    )
    op.create_index("ix_projects_workspace_id", "projects", ["workspace_id"])
    op.create_index("ix_projects_key", "projects", ["key"])
    op.create_index("ix_projects_archived", "projects", ["archived"])

    op.create_table(
        "tasks",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "project_id",
            sa.Integer(),
            sa.ForeignKey("projects.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("number", sa.Integer(), nullable=False),
        sa.Column("title", sa.String(length=500), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("status", sa.String(length=20), nullable=False, server_default="todo"),
        sa.Column("priority", sa.String(length=20), nullable=False, server_default="medium"),
        sa.Column("assignee_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("due_date", sa.Date(), nullable=True),
        sa.Column("position", sa.Float(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("project_id", "number", name="uq_task_project_number"),
    )
    op.create_index("ix_tasks_project_id", "tasks", ["project_id"])
    op.create_index("ix_tasks_status", "tasks", ["status"])
    op.create_index("ix_tasks_priority", "tasks", ["priority"])
    op.create_index("ix_tasks_assignee_id", "tasks", ["assignee_id"])
    op.create_index("ix_tasks_due_date", "tasks", ["due_date"])


def downgrade() -> None:
    op.drop_table("tasks")
    op.drop_table("projects")
    op.drop_table("memberships")
    op.drop_table("workspaces")
    op.drop_index("ix_users_email", table_name="users")
    op.drop_table("users")
