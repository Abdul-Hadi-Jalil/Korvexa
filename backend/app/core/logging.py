"""Structured logging + a request-id context.

Every request gets a request id (from an inbound `X-Request-ID` header if
present, else generated). It's stored in a contextvar so any log line emitted
while handling the request carries it, returned to the client in the response
`X-Request-ID` header, and included in error responses -- so a user-reported
error id can be grepped straight out of the logs.
"""
from __future__ import annotations

import logging
import sys
import time
import uuid
from contextvars import ContextVar

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request

request_id_ctx: ContextVar[str] = ContextVar("request_id", default="-")

logger = logging.getLogger("korvexa")


class _RequestIdFilter(logging.Filter):
    def filter(self, record: logging.LogRecord) -> bool:
        record.request_id = request_id_ctx.get()
        return True


def configure_logging(level: str = "INFO") -> None:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(
        logging.Formatter(
            "%(asctime)s %(levelname)s [%(name)s] [req:%(request_id)s] %(message)s"
        )
    )
    handler.addFilter(_RequestIdFilter())

    root = logging.getLogger()
    root.handlers = [handler]
    root.setLevel(level)


class RequestContextMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        request_id = request.headers.get("X-Request-ID") or uuid.uuid4().hex
        # Stash on request.state too: the 500 handler runs in an outer
        # middleware after this contextvar has been reset, and reads it there.
        request.state.request_id = request_id
        token = request_id_ctx.set(request_id)
        start = time.perf_counter()
        try:
            response = await call_next(request)
        except Exception:
            elapsed_ms = (time.perf_counter() - start) * 1000
            logger.exception(
                "%s %s -> unhandled error (%.1fms)", request.method, request.url.path, elapsed_ms
            )
            raise
        finally:
            request_id_ctx.reset(token)

        elapsed_ms = (time.perf_counter() - start) * 1000
        response.headers["X-Request-ID"] = request_id
        logger.info(
            "%s %s -> %s (%.1fms)",
            request.method,
            request.url.path,
            response.status_code,
            elapsed_ms,
        )
        return response
