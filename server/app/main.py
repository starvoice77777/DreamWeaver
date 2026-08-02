from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI, Response

from app.api.v1.router import router as api_v1_router
from app.core.config import get_settings
from app.core.logging import configure_logging
from app.core.metrics import render_prometheus
from app.core.middleware import ObservabilityASGIMiddleware


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    configure_logging()
    yield


def create_app() -> FastAPI:
    settings = get_settings()
    configure_logging()
    app = FastAPI(
        title=settings.app_name,
        version="0.1.0",
        debug=settings.debug,
        lifespan=lifespan,
    )

    @app.get("/health", tags=["system"], summary="Process health check")
    async def health() -> dict[str, str]:
        return {
            "status": "ok",
            "service": "dreamweaver-api",
            "environment": settings.environment,
        }

    @app.get("/ready", tags=["system"], summary="Dependency readiness check")
    async def ready() -> dict[str, str]:
        # Phase 2: process is ready to accept traffic; deeper dependency probes
        # can be expanded once production health policy is finalized.
        return {
            "status": "ready",
            "service": "dreamweaver-api",
            "environment": settings.environment,
        }

    @app.get("/metrics", tags=["system"], summary="Prometheus-style process metrics")
    async def metrics() -> Response:
        return Response(content=render_prometheus(), media_type="text/plain; version=0.0.4")

    app.include_router(api_v1_router, prefix=settings.api_v1_prefix)
    app.add_middleware(ObservabilityASGIMiddleware)
    return app


app = create_app()
