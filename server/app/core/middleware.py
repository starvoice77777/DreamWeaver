"""Request ID + access log + metrics middleware."""

from __future__ import annotations

import time
import uuid

from app.core.logging import get_logger
from app.core.metrics import observe_request
from app.core.request_context import set_request_id

logger = get_logger("dreamweaver.access")


class ObservabilityASGIMiddleware:
    """Pure ASGI middleware so we can reliably log after the response starts."""

    def __init__(self, app):  # noqa: ANN001
        self.app = app

    async def __call__(self, scope, receive, send):  # noqa: ANN001
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        headers = {k.decode().lower(): v.decode() for k, v in scope.get("headers", [])}
        request_id = (headers.get("x-request-id") or "").strip() or str(uuid.uuid4())
        set_request_id(request_id)
        started = time.perf_counter()
        status_code_holder = {"code": 500}

        async def send_wrapper(message):  # noqa: ANN001
            if message["type"] == "http.response.start":
                status_code_holder["code"] = message["status"]
                raw_headers = list(message.get("headers") or [])
                raw_headers.append((b"x-request-id", request_id.encode()))
                message = {**message, "headers": raw_headers}
            await send(message)

        method = scope.get("method", "GET")
        path = scope.get("path", "/")
        client = scope.get("client")
        client_host = client[0] if client else None

        try:
            await self.app(scope, receive, send_wrapper)
        except Exception:
            duration_ms = (time.perf_counter() - started) * 1000
            observe_request(
                method=method,
                path=path,
                status_code=status_code_holder["code"],
                duration_ms=duration_ms,
            )
            logger.exception(
                "request_failed",
                extra={
                    "request_id": request_id,
                    "method": method,
                    "path": path,
                    "status_code": status_code_holder["code"],
                    "duration_ms": round(duration_ms, 2),
                    "client_host": client_host,
                },
            )
            raise
        else:
            duration_ms = (time.perf_counter() - started) * 1000
            status_code = status_code_holder["code"]
            observe_request(
                method=method,
                path=path,
                status_code=status_code,
                duration_ms=duration_ms,
            )
            log_extra = {
                "request_id": request_id,
                "method": method,
                "path": path,
                "status_code": status_code,
                "duration_ms": round(duration_ms, 2),
                "client_host": client_host,
            }
            if path in {"/health", "/ready", "/metrics"}:
                logger.debug("request", extra=log_extra)
            else:
                logger.info("request", extra=log_extra)
        finally:
            set_request_id(None)
