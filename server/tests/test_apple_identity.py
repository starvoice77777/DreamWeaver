from __future__ import annotations

import hashlib
import json
import time
from datetime import UTC, datetime, timedelta

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa
from jwt.algorithms import RSAAlgorithm

from app.core.config import Settings, get_settings
from app.services.apple_identity import (
    AppleJWKSCache,
    reset_jwks_cache_for_tests,
    verify_apple_identity_token,
)


@pytest.fixture
def rsa_pair():
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    public_jwk = json.loads(RSAAlgorithm.to_jwk(private_key.public_key()))
    public_jwk["kid"] = "test-kid"
    public_jwk["alg"] = "RS256"
    public_jwk["use"] = "sig"
    return private_key, public_jwk


@pytest.fixture
def apple_settings(monkeypatch: pytest.MonkeyPatch) -> Settings:
    monkeypatch.setenv("DW_APPLE_CLIENT_ID", "zhimeng.DreamWeaver")
    monkeypatch.setenv("DW_APPLE_ISSUER", "https://appleid.apple.com")
    monkeypatch.setenv("DW_ENVIRONMENT", "test")
    get_settings.cache_clear()
    reset_jwks_cache_for_tests()
    settings = get_settings()
    yield settings
    get_settings.cache_clear()
    reset_jwks_cache_for_tests()


def _sign(
    private_key,
    *,
    sub: str = "apple-sub-1",
    audience: str = "zhimeng.DreamWeaver",
    issuer: str = "https://appleid.apple.com",
    exp_delta: timedelta = timedelta(minutes=5),
    nonce: str | None = None,
    kid: str = "test-kid",
) -> str:
    now = datetime.now(UTC)
    payload: dict = {
        "iss": issuer,
        "aud": audience,
        "sub": sub,
        "iat": now,
        "exp": now + exp_delta,
    }
    if nonce is not None:
        payload["nonce"] = nonce
    return jwt.encode(
        payload,
        private_key,
        algorithm="RS256",
        headers={"kid": kid},
    )


@pytest.fixture
def jwks_cache(rsa_pair, monkeypatch: pytest.MonkeyPatch) -> AppleJWKSCache:
    _, public_jwk = rsa_pair
    cache = AppleJWKSCache(
        jwks_url="https://example.test/keys",
        cache_seconds=3600,
    )

    async def fake_fetch(self: AppleJWKSCache) -> None:
        self._keys = {public_jwk["kid"]: public_jwk}
        self._fetched_at = time.monotonic()

    monkeypatch.setattr(AppleJWKSCache, "_fetch", fake_fetch)
    return cache


async def test_verify_valid_token(rsa_pair, apple_settings, jwks_cache) -> None:
    private_key, _ = rsa_pair
    token = _sign(private_key)
    claims = await verify_apple_identity_token(
        token,
        settings=apple_settings,
        jwks_cache=jwks_cache,
    )
    assert claims.sub == "apple-sub-1"


async def test_verify_rejects_wrong_audience(rsa_pair, apple_settings, jwks_cache) -> None:
    private_key, _ = rsa_pair
    token = _sign(private_key, audience="com.other.app")
    with pytest.raises(Exception) as exc:
        await verify_apple_identity_token(
            token,
            settings=apple_settings,
            jwks_cache=jwks_cache,
        )
    assert exc.value.status_code == 401


async def test_verify_rejects_expired(rsa_pair, apple_settings, jwks_cache) -> None:
    private_key, _ = rsa_pair
    token = _sign(private_key, exp_delta=timedelta(minutes=-1))
    with pytest.raises(Exception) as exc:
        await verify_apple_identity_token(
            token,
            settings=apple_settings,
            jwks_cache=jwks_cache,
        )
    assert exc.value.status_code == 401


async def test_verify_nonce_sha256(rsa_pair, apple_settings, jwks_cache) -> None:
    private_key, _ = rsa_pair
    raw = "client-nonce-value"
    hashed = hashlib.sha256(raw.encode("utf-8")).hexdigest()
    token = _sign(private_key, nonce=hashed)
    claims = await verify_apple_identity_token(
        token,
        nonce=raw,
        settings=apple_settings,
        jwks_cache=jwks_cache,
    )
    assert claims.sub == "apple-sub-1"


async def test_verify_nonce_mismatch(rsa_pair, apple_settings, jwks_cache) -> None:
    private_key, _ = rsa_pair
    token = _sign(private_key, nonce="expected-hash")
    with pytest.raises(Exception) as exc:
        await verify_apple_identity_token(
            token,
            nonce="other-nonce",
            settings=apple_settings,
            jwks_cache=jwks_cache,
        )
    assert exc.value.status_code == 401
