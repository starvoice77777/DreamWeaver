from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api.v1.router import router as api_v1_router
from app.core.config import get_settings


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    # Database, cache, and object-storage clients will be initialized here
    # as their feature modules are introduced.
    yield


def create_app() -> FastAPI:
    settings = get_settings()
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

    app.include_router(api_v1_router, prefix=settings.api_v1_prefix)
    return app


app = create_app()

