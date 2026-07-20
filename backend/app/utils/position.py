"""Fractional-rank helpers for stable, single-row-update drag-and-drop ordering."""
from __future__ import annotations

from typing import Optional

# Wide gap so many appends can happen before floats lose useful precision.
POSITION_GAP = 1024.0


def next_position(max_position: Optional[float]) -> float:
    """Position for a card appended to the end of a column."""
    return (max_position or 0.0) + POSITION_GAP


def position_between(before: Optional[float], after: Optional[float]) -> float:
    """Position for a card inserted between two existing cards (Phase 2 reorder).

    Passing `before=None` means "insert at the very start"; `after=None` means
    "insert at the very end". Only the moved card's row is ever written.
    """
    if before is None and after is None:
        return POSITION_GAP
    if before is None:
        return after / 2
    if after is None:
        return before + POSITION_GAP
    return (before + after) / 2
