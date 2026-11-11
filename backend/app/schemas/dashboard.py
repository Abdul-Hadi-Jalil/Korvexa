from __future__ import annotations

from sqlmodel import SQLModel


class DashboardStats(SQLModel):
    """Aggregate counts for the current workspace, scoped to non-archived
    projects. Priority counts are among *open* (not done) tasks so they reflect
    current workload.
    """

    projects_active: int
    projects_archived: int

    tasks_total: int
    tasks_todo: int
    tasks_in_progress: int
    tasks_done: int
    tasks_overdue: int

    assigned_to_me_open: int
    assigned_to_me_overdue: int

    priority_high: int
    priority_medium: int
    priority_low: int
