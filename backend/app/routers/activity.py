from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlmodel import Session, select

from app.db import get_session
from app.deps import get_current_workspace
from app.models import ActivityLog, Workspace
from app.routers.tasks import get_task_or_404
from app.schemas.activity import ActivityRead

router = APIRouter(tags=["activity"])


@router.get("/tasks/{task_id}/activity", response_model=list[ActivityRead])
def list_activity(
    task_id: int,
    session: Session = Depends(get_session),
    workspace: Workspace = Depends(get_current_workspace),
) -> list[ActivityLog]:
    # 404s if the task isn't in this workspace -- same isolation rule as tasks.
    get_task_or_404(session, workspace, task_id)
    return session.exec(
        select(ActivityLog)
        .where(ActivityLog.task_id == task_id)
        .order_by(ActivityLog.created_at.desc(), ActivityLog.id.desc())
    ).all()
