import uuid

from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

from app.core.metrics import reset_metrics
from app.main import create_app
from app.models.audit import AuditEvent


async def test_health_echoes_request_id() -> None:
    async with AsyncClient(
        transport=ASGITransport(app=create_app()),
        base_url="http://test",
    ) as client:
        response = await client.get("/health", headers={"X-Request-ID": "test-req-123"})

    assert response.status_code == 200
    assert response.headers.get("x-request-id") == "test-req-123"


async def test_health_generates_request_id() -> None:
    async with AsyncClient(
        transport=ASGITransport(app=create_app()),
        base_url="http://test",
    ) as client:
        response = await client.get("/health")

    assert response.status_code == 200
    assert response.headers.get("x-request-id")


async def test_metrics_endpoint() -> None:
    reset_metrics()
    async with AsyncClient(
        transport=ASGITransport(app=create_app()),
        base_url="http://test",
    ) as client:
        await client.get("/health")
        response = await client.get("/metrics")

    assert response.status_code == 200
    body = response.text
    assert "http_requests_total" in body
    assert 'path="/health"' in body


async def test_login_and_logout_carry_request_id(client) -> None:  # noqa: ANN001
    login = await client.post(
        "/v1/auth/apple",
        json={"identity_token": "dev:obs-audit-user", "nickname": "审计"},
        headers={"X-Request-ID": "audit-login-1"},
    )
    assert login.status_code == 200, login.text
    assert login.headers.get("x-request-id") == "audit-login-1"

    tokens = login.json()
    logout = await client.post(
        "/v1/auth/logout",
        headers={
            "Authorization": f"Bearer {tokens['access_token']}",
            "X-Request-ID": "audit-logout-1",
        },
    )
    assert logout.status_code == 204
    assert logout.headers.get("x-request-id") == "audit-logout-1"


async def test_login_persists_audit_row(client) -> None:  # noqa: ANN001
    response = await client.post(
        "/v1/auth/apple",
        json={"identity_token": "dev:obs-db-audit", "nickname": "库审计"},
        headers={"X-Request-ID": "audit-db-1"},
    )
    assert response.status_code == 200, response.text
    user_id = uuid.UUID(response.json()["user_id"])

    transport = client._transport  # noqa: SLF001
    app = transport.app  # type: ignore[attr-defined]
    session_factory = app.state.session_factory
    async with session_factory() as session:
        rows = (
            await session.scalars(
                select(AuditEvent).where(
                    AuditEvent.action == "auth.login",
                    AuditEvent.user_id == user_id,
                )
            )
        ).all()
        assert len(rows) == 1
        assert rows[0].request_id == "audit-db-1"
