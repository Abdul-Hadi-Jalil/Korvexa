"""Create in-app notifications (and fire the email stub).

Notifications are added to the caller's session but not committed here, so
they land atomically with the mutation that triggered them.
"""
from __future__ import annotations

import re
from typing import Optional

from sqlmodel import Session, select

from app.models import Membership, Notification, User
from app.services.email import send_email

# @mentions: a run of word chars / dots / hyphens after an @, e.g. "@jane.doe".
_MENTION_RE = re.compile(r"@([\w.\-]+)")


def notify_assignment(
    session: Session,
    *,
    workspace_id: int,
    task_id: int,
    task_title: str,
    assignee_id: int,
    actor: User,
) -> Optional[Notification]:
    # Don't notify someone for assigning a task to themselves.
    if assignee_id == actor.id:
        return None
    notification = Notification(
        user_id=assignee_id,
        workspace_id=workspace_id,
        type="assigned",
        task_id=task_id,
        actor_id=actor.id,
        message=f'{actor.name} assigned you "{task_title}"',
    )
    session.add(notification)
    assignee = session.get(User, assignee_id)
    if assignee is not None:
        send_email(assignee.email, "You were assigned a task", notification.message)
    return notification


def notify_mentions(
    session: Session,
    *,
    workspace_id: int,
    task_id: int,
    comment_id: int,
    body: str,
    actor: User,
) -> list[Notification]:
    """Create a notification for each workspace member @mentioned in `body`.

    A handle matches a member if it equals the part of their email before the
    @, or their name with spaces removed (both case-insensitively). Only
    members of this workspace can be mentioned -- no cross-tenant leakage.
    """
    handles = {h.lower() for h in _MENTION_RE.findall(body)}
    if not handles:
        return []

    members = session.exec(
        select(User)
        .join(Membership, Membership.user_id == User.id)
        .where(Membership.workspace_id == workspace_id)
    ).all()

    created: list[Notification] = []
    for member in members:
        if member.id == actor.id:
            continue
        local = member.email.split("@")[0].lower()
        name_handle = member.name.replace(" ", "").lower()
        if local in handles or name_handle in handles:
            notification = Notification(
                user_id=member.id,
                workspace_id=workspace_id,
                type="mention",
                task_id=task_id,
                comment_id=comment_id,
                actor_id=actor.id,
                message=f"{actor.name} mentioned you in a comment",
            )
            session.add(notification)
            send_email(member.email, "You were mentioned", notification.message)
            created.append(notification)
    return created
