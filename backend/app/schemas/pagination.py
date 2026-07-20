from __future__ import annotations

from typing import Generic, TypeVar

from pydantic import BaseModel

T = TypeVar("T")


class Page(BaseModel, Generic[T]):
    """Standard limit/offset pagination envelope used by list endpoints."""

    items: list[T]
    total: int
    limit: int
    offset: int
