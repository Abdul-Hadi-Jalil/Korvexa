from __future__ import annotations

from datetime import datetime

from pydantic import EmailStr
from sqlmodel import Field, SQLModel


class RegisterRequest(SQLModel):
    email: EmailStr
    name: str = Field(min_length=1, max_length=255)
    password: str = Field(min_length=8, max_length=128)


class LoginRequest(SQLModel):
    email: EmailStr
    password: str


class RefreshRequest(SQLModel):
    refresh_token: str


class TokenPair(SQLModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class UserRead(SQLModel):
    id: int
    email: str
    name: str
    created_at: datetime
