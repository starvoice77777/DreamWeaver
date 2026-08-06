from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from typing import Annotated

from fastapi import Depends, FastAPI, Response
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.router import router as api_v1_router
from app.core.config import get_settings
from app.core.logging import configure_logging
from app.core.metrics import render_prometheus
from app.core.middleware import ObservabilityASGIMiddleware
from app.core.readiness import probe_database, probe_redis
from app.db.session import get_db_session, session_factory


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    configure_logging()
    settings = get_settings()
    if settings.force_reseed_catalog_enabled and not settings.is_production:
        from app.services.seed_catalog import reseed_official_catalog

        async with session_factory() as session:
            await reseed_official_catalog(session)
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

    @app.get(
        "/ready",
        tags=["system"],
        summary="Dependency readiness check",
        response_model=None,
    )
    async def ready(
        session: Annotated[AsyncSession, Depends(get_db_session)],
    ) -> JSONResponse | dict[str, str]:
        checks: dict[str, str] = {
            "service": "dreamweaver-api",
            "environment": settings.environment,
        }
        try:
            await probe_database(session)
            checks["database"] = "ok"
        except Exception as exc:  # noqa: BLE001 — surface probe failure as not ready
            checks["status"] = "not_ready"
            checks["database"] = "error"
            checks["detail"] = str(exc)
            return JSONResponse(status_code=503, content=checks)

        if settings.ready_probe_redis:
            try:
                await probe_redis(settings.redis_url)
                checks["redis"] = "ok"
            except Exception as exc:  # noqa: BLE001
                checks["status"] = "not_ready"
                checks["redis"] = "error"
                checks["detail"] = str(exc)
                return JSONResponse(status_code=503, content=checks)
        else:
            checks["redis"] = "skipped"

        # Object storage (MinIO/OSS) is not required for content API readiness.
        checks["status"] = "ready"
        return checks

    @app.get("/metrics", tags=["system"], summary="Prometheus-style process metrics")
    async def metrics() -> Response:
        return Response(content=render_prometheus(), media_type="text/plain; version=0.0.4")

    app.include_router(api_v1_router, prefix=settings.api_v1_prefix)
    app.add_middleware(ObservabilityASGIMiddleware)
    return app


app = create_app()
