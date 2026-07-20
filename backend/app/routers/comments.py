from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, func, select

from app.db import get_session
from app.deps import get_current_user, get_current_workspace
from app.models import Comment, Project, Task, User, Workspace
from app.schemas.comment import CommentCreate, CommentRead, CommentUpdate
from app.schemas.pagination import Page

router = APIRouter(tags=["comments"])


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _get_task_or_404(session: Session, workspace: Workspace, task_id: int) -> Task:
    task = session.get(Task, task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    project = session.get(Project, task.project_id)
    if project is None or project.workspace_id != workspace.id:
        raise HTTPException(status_code=404, detail="Task not found")
    return task


def _to_read(comment: Comment, author_name: str | None) -> CommentRead:
    return CommentRead(
        id=comment.id,
        task_id=comment.task_id,
        author_id=comment.author_id,
        author_name=author_name,
        body=comment.body,
        created_at=comment.created_at,
        updated_at=comment.updated_at,
    )


def _get_comment_or_404(session: Session, workspace: Workspace, comment_id: int) -> Comment:
    comment = session.get(Comment, comment_id)
    if comment is None:
        raise HTTPException(status_code=404, detail="Comment not found")
    # Ensure the comment's task belongs to this workspace.
    _get_task_or_404(session, workspace, comment.task_id)
    return comment


@router.get("/tasks/{task_id}/comments", response_model=Page[CommentRead])
def list_comments(
    task_id: int,
    limit: int = 50,
    offset: int = 0,
    session: Session = Depends(get_session),
    workspace: Workspace = Depends(get_current_workspace),
) -> Page[CommentRead]:
    _get_task_or_404(session, workspace, task_id)
    limit = max(1, min(limit, 200))
    offset = max(0, offset)

    total = session.exec(
        select(func.count()).select_from(Comment).where(Comment.task_id == task_id)
    ).one()
    rows = session.exec(
        select(Comment, User.name)
        .join(User, Comment.author_id == User.id)
        .where(Comment.task_id == task_id)
        .order_by(Comment.created_at)
        .limit(limit)
        .offset(offset)
    ).all()
    items = [_to_read(comment, author_name) for comment, author_name in rows]
    return Page[CommentRead](items=items, total=total, limit=limit, offset=offset)


@router.post("/tasks/{task_id}/comments", response_model=CommentRead, status_code=201)
def create_comment(
    task_id: int,
    payload: CommentCreate,
    session: Session = Depends(get_session),
    workspace: Workspace = Depends(get_current_workspace),
    user: User = Depends(get_current_user),
) -> CommentRead:
    _get_task_or_404(session, workspace, task_id)
    comment = Comment(task_id=task_id, author_id=user.id, body=payload.body)
    session.add(comment)
    session.commit()
    session.refresh(comment)
    return _to_read(comment, user.name)


@router.patch("/comments/{comment_id}", response_model=CommentRead)
def update_comment(
    comment_id: int,
    payload: CommentUpdate,
    session: Session = Depends(get_session),
    workspace: Workspace = Depends(get_current_workspace),
    user: User = Depends(get_current_user),
) -> CommentRead:
    comment = _get_comment_or_404(session, workspace, comment_id)
    if comment.author_id != user.id:
        raise HTTPException(status_code=403, detail="You can only edit your own comments")
    comment.body = payload.body
    comment.updated_at = _utcnow()
    session.add(comment)
    session.commit()
    session.refresh(comment)
    return _to_read(comment, user.name)


@router.delete("/comments/{comment_id}", status_code=204)
def delete_comment(
    comment_id: int,
    session: Session = Depends(get_session),
    workspace: Workspace = Depends(get_current_workspace),
    user: User = Depends(get_current_user),
) -> None:
    comment = _get_comment_or_404(session, workspace, comment_id)
    if comment.author_id != user.id:
        raise HTTPException(status_code=403, detail="You can only delete your own comments")
    session.delete(comment)
    session.commit()
