from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, func, select

from app.db import get_session
from app.deps import get_current_user, get_current_workspace
from app.models import Notification, User, Workspace
from app.schemas.workspace import NotificationRead

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("", response_model=list[NotificationRead])
def list_notifications(
    unread_only: bool = False,
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
    workspace: Workspace = Depends(get_current_workspace),
) -> list[Notification]:
    query = select(Notification).where(
        Notification.user_id == user.id, Notification.workspace_id == workspace.id
    )
    if unread_only:
        query = query.where(Notification.read == False)  # noqa: E712
    return session.exec(query.order_by(Notification.created_at.desc(), Notification.id.desc())).all()


@router.get("/unread_count")
def unread_count(
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
    workspace: Workspace = Depends(get_current_workspace),
) -> dict[str, int]:
    count = session.exec(
        select(func.count())
        .select_from(Notification)
        .where(
            Notification.user_id == user.id,
            Notification.workspace_id == workspace.id,
            Notification.read == False,  # noqa: E712
        )
    ).one()
    return {"unread": count}


@router.post("/{notification_id}/read", response_model=NotificationRead)
def mark_read(
    notification_id: int,
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
) -> Notification:
    notification = session.get(Notification, notification_id)
    if notification is None or notification.user_id != user.id:
        raise HTTPException(status_code=404, detail="Notification not found")
    notification.read = True
    session.add(notification)
    session.commit()
    session.refresh(notification)
    return notification


@router.post("/read_all")
def mark_all_read(
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
    workspace: Workspace = Depends(get_current_workspace),
) -> dict[str, int]:
    rows = session.exec(
        select(Notification).where(
            Notification.user_id == user.id,
            Notification.workspace_id == workspace.id,
            Notification.read == False,  # noqa: E712
        )
    ).all()
    for notification in rows:
        notification.read = True
        session.add(notification)
    session.commit()
    return {"marked": len(rows)}
