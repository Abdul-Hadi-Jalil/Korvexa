"""Shared slowapi limiter.

Used to throttle auth endpoints (register/login) against brute-force. The
limit value comes from settings (`RATE_LIMIT_AUTH`, default "10/minute").
Rate limiting keys off the client IP.
"""
from __future__ import annotations

from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
