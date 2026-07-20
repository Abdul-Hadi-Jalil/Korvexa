"""Derive short, human-readable project keys (e.g. "Marketing Site" -> MARK)."""
from __future__ import annotations

import re

_WORD_RE = re.compile(r"[A-Za-z0-9]+")


def derive_project_key(name: str) -> str:
    """Best-effort initial guess at a project key from its name.

    Single word -> first 4 letters ("Marketing" -> "MARK").
    Multiple words -> initials, up to 5 ("Marketing Site Revamp" -> "MSR").
    Uniqueness within the workspace is handled separately by `unique_project_key`.
    """
    words = _WORD_RE.findall(name)
    if not words:
        base = "PROJ"
    elif len(words) == 1:
        word = words[0].upper()
        base = word[:4] if len(word) >= 2 else (word + "XXXX")[:4]
    else:
        base = "".join(word[0].upper() for word in words[:5])

    base = re.sub(r"[^A-Z0-9]", "", base)
    if len(base) < 2:
        base = (base + "PROJ")[:3]
    return base[:10]


def unique_project_key(base: str, existing: set[str]) -> str:
    """Append a numeric suffix until `base` no longer collides with `existing`."""
    base = base.upper()
    if base not in existing:
        return base
    counter = 2
    while True:
        suffix = str(counter)
        candidate = f"{base[: max(1, 10 - len(suffix))]}{suffix}"
        if candidate not in existing:
            return candidate
        counter += 1
