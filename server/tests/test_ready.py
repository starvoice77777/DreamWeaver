from unittest.mock import AsyncMock

from httpx import ASGITransport, AsyncClient

from app.core.config import get_settings
from app.main import create_app


async def test_ready_ok(client, monkeypatch) -> None:  # noqa: ANN001
    monkeypatch.setattr("app.main.probe_redis", AsyncMock(return_value=None))
    monkeypatch.setenv("DW_READY_PROBE_REDIS", "true")
    get_settings.cache_clear()
    try:
        # Recreate app so settings pick up env; reuse DB override from client fixture.
        response = await client.get("/ready")
        # client app was created before env change — probe_redis is patched on app.main
        assert response.status_code == 200
        body = response.json()
        assert body["status"] == "ready"
        assert body["database"] == "ok"
    finally:
        monkeypatch.delenv("DW_READY_PROBE_REDIS", raising=False)
        get_settings.cache_clear()


async def test_ready_redis_failure_returns_503(client, monkeypatch) -> None:  # noqa: ANN001
    async def boom(_url: str) -> None:
        raise ConnectionError("redis down")

    monkeypatch.setattr("app.main.probe_redis", boom)
    # Ensure redis probe is enabled on the already-built settings used by create_app
    settings = get_settings()
    monkeypatch.setattr(settings, "ready_probe_redis", True)

    response = await client.get("/ready")
    assert response.status_code == 503
    body = response.json()
    assert body["status"] == "not_ready"
    assert body["redis"] == "error"


async def test_ready_skips_redis_when_disabled(monkeypatch) -> None:
    monkeypatch.setenv("DW_READY_PROBE_REDIS", "false")
    get_settings.cache_clear()
    try:
        from collections.abc import AsyncIterator

        from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

        import app.models  # noqa: F401
        from app.db.base import Base
        from app.db.session import get_db_session

        engine = create_async_engine("sqlite+aiosqlite:///:memory:")
        session_factory = async_sessionmaker(engine, expire_on_commit=False)
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)

        async def override_db() -> AsyncIterator[AsyncSession]:
            async with session_factory() as session:
                yield session

        app = create_app()
        app.dependency_overrides[get_db_session] = override_db
        async with AsyncClient(
            transport=ASGITransport(app=app),
            base_url="http://test",
        ) as http:
            response = await http.get("/ready")
        assert response.status_code == 200
        assert response.json()["redis"] == "skipped"
        await engine.dispose()
    finally:
        monkeypatch.delenv("DW_READY_PROBE_REDIS", raising=False)
        get_settings.cache_clear()
