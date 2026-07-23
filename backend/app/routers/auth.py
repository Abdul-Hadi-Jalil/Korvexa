from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlmodel import Session, select

from app.core.config import get_settings
from app.core.security import (
    REFRESH_TOKEN_TYPE,
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)
from app.core.rate_limit import limiter
from app.db import get_session
from app.deps import get_current_user
from app.models import User
from app.schemas.auth import LoginRequest, RefreshRequest, RegisterRequest, TokenPair, UserRead
from app.services.workspaces import create_workspace, user_has_workspace

router = APIRouter(prefix="/auth", tags=["auth"])
settings = get_settings()


def _token_pair(user_id: int) -> TokenPair:
    return TokenPair(
        access_token=create_access_token(user_id),
        refresh_token=create_refresh_token(user_id),
    )


@router.post("/register", response_model=TokenPair, status_code=201)
@limiter.limit(settings.rate_limit_auth)
def register(
    request: Request,
    payload: RegisterRequest,
    session: Session = Depends(get_session),
) -> TokenPair:
    existing = session.exec(select(User).where(User.email == payload.email)).first()

    if existing is not None and existing.password_hash is not None:
        raise HTTPException(status_code=409, detail="Email already registered")

    if existing is not None:
        # A passwordless placeholder created by an invite -- claim it.
        existing.name = payload.name
        existing.password_hash = hash_password(payload.password)
        session.add(existing)
        user = existing
    else:
        user = User(
            email=payload.email, name=payload.name, password_hash=hash_password(payload.password)
        )
        session.add(user)
    session.flush()

    # Everyone gets a personal workspace on first registration; invited users
    # keep their invited memberships too.
    if not user_has_workspace(session, user.id):
        create_workspace(session, name=f"{payload.name}'s Workspace", owner=user, commit=False)

    session.commit()
    return _token_pair(user.id)


@router.post("/login", response_model=TokenPair)
@limiter.limit(settings.rate_limit_auth)
def login(
    request: Request,
    payload: LoginRequest,
    session: Session = Depends(get_session),
) -> TokenPair:
    user = session.exec(select(User).where(User.email == payload.email)).first()
    if user is None or user.password_hash is None or not verify_password(
        payload.password, user.password_hash
    ):
        # Same message whether the email is unknown or the password is wrong.
        raise HTTPException(status_code=401, detail="Invalid email or password")
    return _token_pair(user.id)


@router.post("/refresh", response_model=TokenPair)
def refresh(payload: RefreshRequest, session: Session = Depends(get_session)) -> TokenPair:
    user_id = decode_token(payload.refresh_token, expected_type=REFRESH_TOKEN_TYPE)
    if user_id is None or session.get(User, user_id) is None:
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token")
    return _token_pair(user_id)


@router.get("/me", response_model=UserRead)
def me(user: User = Depends(get_current_user)) -> User:
    return user
