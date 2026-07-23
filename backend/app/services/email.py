"""Email delivery stub.

Phase 3 keeps in-app notifications as the real channel; email is a stub that
just logs. Swapping this for a real provider (SES/SendGrid/SMTP) later is a
one-file change.
"""
from __future__ import annotations

import logging

logger = logging.getLogger("korvexa.email")


def send_email(to: str, subject: str, body: str) -> None:
    logger.info("stub email -> %s | %s | %s", to, subject, body)
