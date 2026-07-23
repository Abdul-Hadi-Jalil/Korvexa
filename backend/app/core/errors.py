"""Consistent error-response schema across the API.

Every error -- raised HTTPException, request validation failure, or an
unhandled exception -- comes back as:

    {"detail": "<human message>", "request_id": "<id>", "errors": [...]?}

`detail` is kept as the primary human-readable message (FastAPI's convention,
and what the Flutter client reads), so this standardizes the envelope without
breaking existing clients. `errors` is only present for validation failures.
"""
from __future__ import annotations

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.logging import logger, request_id_ctx


def _request_id(request: Request) -> str:
    return getattr(request.state, "request_id", None) or request_id_ctx.get()


def _payload(request: Request, detail: object, **extra) -> dict:
    return {"detail": detail, "request_id": _request_id(request), **extra}


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(StarletteHTTPException)
    async def _http_exc(request: Request, exc: StarletteHTTPException) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status_code,
            content=_payload(request, exc.detail),
            headers=getattr(exc, "headers", None),
        )

    @app.exception_handler(RequestValidationError)
    async def _validation_exc(request: Request, exc: RequestValidationError) -> JSONResponse:
        # Strip non-JSON-serializable bits (e.g. exception ctx) from errors.
        errors = [
            {"loc": list(err.get("loc", [])), "msg": err.get("msg"), "type": err.get("type")}
            for err in exc.errors()
        ]
        return JSONResponse(
            status_code=422,
            content=_payload(request, "Validation error", errors=errors),
        )

    @app.exception_handler(Exception)
    async def _unhandled_exc(request: Request, exc: Exception) -> JSONResponse:
        # The request-context middleware already logged the traceback.
        logger.error("Unhandled exception on %s %s", request.method, request.url.path)
        return JSONResponse(status_code=500, content=_payload(request, "Internal server error"))
