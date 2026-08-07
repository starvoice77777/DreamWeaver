from __future__ import annotations

import json
import time
import uuid
from datetime import UTC, datetime, timedelta

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa
from jwt.algorithms import RSAAlgorithm

from app.core.config import get_settings
from app.models.content import Scene
from app.services.apple_identity import AppleJWKSCache, reset_jwks_cache_for_tests
from app.services.seed_catalog import DEFAULT_SCENE_ID


async def test_bootstrap_and_scenes(client) -> None:
    bootstrap = await client.get("/v1/bootstrap")
    assert bootstrap.status_code == 200
    payload = bootstrap.json()
    assert payload["api_version"] == "v1"
    assert payload["default_scene_id"] == str(DEFAULT_SCENE_ID)
    assert len(payload["scenes"]) >= 2
    assert payload["greeting"]

    scenes = await client.get("/v1/scenes")
    assert scenes.status_code == 200
    assert any(item["name"] == "洗头陪伴" for item in scenes.json())

    detail = await client.get(f"/v1/scenes/{DEFAULT_SCENE_ID}")
    assert detail.status_code == 200
    body = detail.json()
    assert body["name"] == "洗头陪伴"
    assert len(body["tracks"]) >= 3
    assert body["tracks"][0]["position"]["radius"] > 0

    presets = await client.get(f"/v1/scenes/{DEFAULT_SCENE_ID}/presets")
    assert presets.status_code == 200
    assert any(item["name"] == "洗头轻声" for item in presets.json())


async def test_emotional_fluid_scene_retired(client) -> None:
    """An existing fluid row is unpublished while its reusable renderer remains."""
    fluid_id = uuid.UUID("a1111111-1111-4111-8111-11111111110e")
    factory = client._transport.app.state.session_factory  # type: ignore[attr-defined]
    async with factory() as session:
        session.add(
            Scene(
                id=fluid_id,
                name="流光溢彩",
                subtitle="legacy",
                description="legacy",
                category="lightMusic",
                tags=["色彩"],
                palette={"top": 0x24324A, "mid": 0x4B4668, "bottom": 0x163A4A},
                visual_style="emotionalFluid",
                is_published=True,
            )
        )
        await session.commit()

    scenes = await client.get("/v1/scenes")
    assert scenes.status_code == 200
    match = next((item for item in scenes.json() if item["id"] == str(fluid_id)), None)
    assert match is None

    detail = await client.get(f"/v1/scenes/{fluid_id}")
    assert detail.status_code == 404


async def test_apple_auth_dev_token(client) -> None:
    response = await client.post(
        "/v1/auth/apple",
        json={"identity_token": "dev:phase2-tester", "nickname": "测试者"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["nickname"] == "测试者"
    assert body["access_token"]
    assert body["refresh_token"]
    assert body["token_type"] == "bearer"


async def test_apple_auth_rejects_raw_garbage(client) -> None:
    """Non-JWT tokens must no longer be accepted via hash fallback."""
    response = await client.post(
        "/v1/auth/apple",
        json={"identity_token": "not-a-jwt-at-all"},
    )
    assert response.status_code == 401


async def test_apple_auth_jwks_token(client, monkeypatch: pytest.MonkeyPatch) -> None:
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    public_jwk = json.loads(RSAAlgorithm.to_jwk(private_key.public_key()))
    public_jwk["kid"] = "api-test-kid"
    public_jwk["alg"] = "RS256"
    public_jwk["use"] = "sig"

    async def fake_fetch(self: AppleJWKSCache) -> None:
        self._keys = {public_jwk["kid"]: public_jwk}
        self._fetched_at = time.monotonic()

    monkeypatch.setattr(AppleJWKSCache, "_fetch", fake_fetch)
    monkeypatch.setenv("DW_APPLE_CLIENT_ID", "zhimeng.DreamWeaver")
    get_settings.cache_clear()
    reset_jwks_cache_for_tests()

    now = datetime.now(UTC)
    token = jwt.encode(
        {
            "iss": "https://appleid.apple.com",
            "aud": "zhimeng.DreamWeaver",
            "sub": "real-apple-sub",
            "iat": now,
            "exp": now + timedelta(minutes=5),
        },
        private_key,
        algorithm="RS256",
        headers={"kid": "api-test-kid"},
    )

    response = await client.post(
        "/v1/auth/apple",
        json={"identity_token": token, "nickname": "苹果用户"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["nickname"] == "苹果用户"
    assert body["access_token"]

    # Same sub returns same user, nickname update allowed.
    again = await client.post(
        "/v1/auth/apple",
        json={"identity_token": token, "nickname": "夜行者"},
    )
    assert again.status_code == 200
    assert again.json()["user_id"] == body["user_id"]
    assert again.json()["nickname"] == "夜行者"

    get_settings.cache_clear()
    reset_jwks_cache_for_tests()


async def test_apple_auth_dev_disabled(client, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("DW_ALLOW_DEV_APPLE_AUTH", "false")
    get_settings.cache_clear()
    try:
        response = await client.post(
            "/v1/auth/apple",
            json={"identity_token": "dev:blocked"},
        )
        assert response.status_code == 401
        assert "Dev Apple auth" in response.json()["detail"]
    finally:
        get_settings.cache_clear()
