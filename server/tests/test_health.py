from httpx import ASGITransport, AsyncClient

from app.main import create_app


async def test_health() -> None:
    async with AsyncClient(
        transport=ASGITransport(app=create_app()),
        base_url="http://test",
    ) as client:
        response = await client.get("/health")

    assert response.status_code == 200
    assert response.json() == {
        "status": "ok",
        "service": "dreamweaver-api",
        "environment": "development",
    }


async def test_api_version() -> None:
    async with AsyncClient(
        transport=ASGITransport(app=create_app()),
        base_url="http://test",
    ) as client:
        response = await client.get("/v1/")

    assert response.status_code == 200
    assert response.json() == {"name": "DreamWeaver API", "version": "v1"}

