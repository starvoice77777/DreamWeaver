from __future__ import annotations

import hashlib
import time
from dataclasses import dataclass
from typing import Any

import httpx
import jwt
from fastapi import HTTPException, status
from jwt.algorithms import RSAAlgorithm

from app.core.config import Settings, get_settings

DEV_TOKEN_PREFIX = "dev:"


@dataclass(frozen=True, slots=True)
class AppleIdentityClaims:
    sub: str
    email: str | None = None
    email_verified: bool | None = None
    is_private_email: bool | None = None


class AppleJWKSCache:
    """Fetches and caches Apple's JWKS; refreshes on TTL expiry or unknown kid."""

    def __init__(self, *, jwks_url: str, cache_seconds: int) -> None:
        self._jwks_url = jwks_url
        self._cache_seconds = cache_seconds
        self._keys: dict[str, dict[str, Any]] = {}
        self._fetched_at: float = 0.0

    def clear(self) -> None:
        self._keys.clear()
        self._fetched_at = 0.0

    def _expired(self) -> bool:
        if not self._keys:
            return True
        return (time.monotonic() - self._fetched_at) >= self._cache_seconds

    async def _fetch(self) -> None:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(self._jwks_url)
            response.raise_for_status()
            payload = response.json()
        keys = payload.get("keys")
        if not isinstance(keys, list) or not keys:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Apple JWKS response missing keys",
            )
        by_kid: dict[str, dict[str, Any]] = {}
        for key in keys:
            if not isinstance(key, dict):
                continue
            kid = key.get("kid")
            if isinstance(kid, str) and kid:
                by_kid[kid] = key
        if not by_kid:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Apple JWKS response had no usable kids",
            )
        self._keys = by_kid
        self._fetched_at = time.monotonic()

    async def get_jwk(self, kid: str) -> dict[str, Any]:
        if self._expired():
            await self._fetch()
        key = self._keys.get(kid)
        if key is not None:
            return key
        # Apple may have rotated keys; force one refresh.
        await self._fetch()
        key = self._keys.get(kid)
        if key is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Apple identity token key id not recognized",
            )
        return key


_jwks_cache: AppleJWKSCache | None = None


def get_jwks_cache(settings: Settings | None = None) -> AppleJWKSCache:
    global _jwks_cache
    cfg = settings or get_settings()
    if _jwks_cache is None:
        _jwks_cache = AppleJWKSCache(
            jwks_url=cfg.apple_jwks_url,
            cache_seconds=cfg.apple_jwks_cache_seconds,
        )
    return _jwks_cache


def reset_jwks_cache_for_tests() -> None:
    global _jwks_cache
    _jwks_cache = None


def parse_dev_apple_sub(identity_token: str) -> str | None:
    if not identity_token.startswith(DEV_TOKEN_PREFIX):
        return None
    return identity_token.removeprefix(DEV_TOKEN_PREFIX).strip() or "dev-user"


def _as_bool(value: Any) -> bool | None:
    if value is None:
        return None
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        lowered = value.strip().lower()
        if lowered in {"true", "1", "yes"}:
            return True
        if lowered in {"false", "0", "no"}:
            return False
    return None


def _nonce_matches(claim: str | None, provided: str | None) -> bool:
    """Apple stores SHA-256(hex) of the client nonce; also accept raw equality."""
    if provided is None:
        return True
    if claim is None:
        return False
    if claim == provided:
        return True
    hashed = hashlib.sha256(provided.encode("utf-8")).hexdigest()
    return claim == hashed


async def verify_apple_identity_token(
    identity_token: str,
    *,
    nonce: str | None = None,
    settings: Settings | None = None,
    jwks_cache: AppleJWKSCache | None = None,
) -> AppleIdentityClaims:
    cfg = settings or get_settings()
    cache = jwks_cache or get_jwks_cache(cfg)

    try:
        header = jwt.get_unverified_header(identity_token)
    except jwt.InvalidTokenError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Malformed Apple identity token",
        ) from exc

    kid = header.get("kid")
    alg = header.get("alg")
    if not isinstance(kid, str) or not kid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Apple identity token missing kid",
        )
    if alg != "RS256":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Apple identity token must use RS256",
        )

    try:
        jwk = await cache.get_jwk(kid)
        public_key = RSAAlgorithm.from_jwk(jwk)
        payload = jwt.decode(
            identity_token,
            key=public_key,
            algorithms=["RS256"],
            audience=cfg.apple_client_id,
            issuer=cfg.apple_issuer,
            options={"require": ["exp", "iat", "sub"]},
        )
    except HTTPException:
        raise
    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to fetch Apple JWKS",
        ) from exc
    except jwt.PyJWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Apple identity token",
        ) from exc

    sub = payload.get("sub")
    if not isinstance(sub, str) or not sub.strip():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Apple identity token missing sub",
        )

    claim_nonce = payload.get("nonce")
    if claim_nonce is not None and not isinstance(claim_nonce, str):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Apple identity token has invalid nonce",
        )
    if not _nonce_matches(claim_nonce, nonce):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Apple identity token nonce mismatch",
        )

    return AppleIdentityClaims(
        sub=sub.strip(),
        email=payload.get("email") if isinstance(payload.get("email"), str) else None,
        email_verified=_as_bool(payload.get("email_verified")),
        is_private_email=_as_bool(payload.get("is_private_email")),
    )
