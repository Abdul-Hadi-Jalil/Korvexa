"""Password hashing (bcrypt) and JWT access/refresh token helpers.

bcrypt is used directly rather than via passlib: passlib 1.7.x's bcrypt
backend probes the library with a >72-byte password, which modern bcrypt
(>=4.1) rejects, raising on import. The algorithm and security properties are
identical -- this just avoids the broken shim.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any, Optional

import bcrypt
from jose import JWTError, jwt

from app.core.config import get_settings

settings = get_settings()

ACCESS_TOKEN_TYPE = "access"
REFRESH_TOKEN_TYPE = "refresh"

# bcrypt only considers the first 72 bytes of the password; enforce it
# explicitly so longer inputs hash/verify consistently instead of erroring.
_BCRYPT_MAX_BYTES = 72


def hash_password(password: str) -> str:
    salt = bcrypt.gensalt(rounds=settings.bcrypt_rounds)
    return bcrypt.hashpw(password.encode("utf-8")[:_BCRYPT_MAX_BYTES], salt).decode("utf-8")


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return bcrypt.checkpw(password.encode("utf-8")[:_BCRYPT_MAX_BYTES], password_hash.encode("utf-8"))
    except ValueError:
        return False


def _create_token(subject: str, token_type: str, expires_delta: timedelta) -> str:
    now = datetime.now(timezone.utc)
    payload: dict[str, Any] = {
        "sub": subject,
        "type": token_type,
        "iat": now,
        "exp": now + expires_delta,
    }
    return jwt.encode(payload, settings.secret_key, algorithm=settings.algorithm)


def create_access_token(user_id: int) -> str:
    return _create_token(
        str(user_id), ACCESS_TOKEN_TYPE, timedelta(minutes=settings.access_token_expire_minutes)
    )


def create_refresh_token(user_id: int) -> str:
    return _create_token(
        str(user_id), REFRESH_TOKEN_TYPE, timedelta(minutes=settings.refresh_token_expire_minutes)
    )


def decode_token(token: str, expected_type: Optional[str] = None) -> Optional[int]:
    """Return the user id encoded in the token, or None if it's invalid,
    expired, or not of the expected type.
    """
    try:
        payload = jwt.decode(token, settings.secret_key, algorithms=[settings.algorithm])
    except JWTError:
        return None
    if expected_type is not None and payload.get("type") != expected_type:
        return None
    subject = payload.get("sub")
    if subject is None:
        return None
    try:
        return int(subject)
    except (TypeError, ValueError):
        return None
