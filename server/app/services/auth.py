from __future__ import annotations

import hashlib
import secrets
import uuid
from datetime import UTC, datetime, timedelta

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import get_settings
from app.models.user import AppleIdentity, Session, User, UserSettings
from app.schemas.content import AuthTokensOut
from app.services.apple_identity import parse_dev_apple_sub, verify_apple_identity_token
from app.services.seed_catalog import DEFAULT_SCENE_ID

ACCESS_TOKEN_TTL = timedelta(days=30)
REFRESH_TOKEN_TTL = timedelta(days=90)


def hash_token(raw: str) -> str:
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def _issue_tokens(
    session: AsyncSession,
    user: User,
    *,
    device_label: str | None,
) -> tuple[str, str, Session]:
    access_token = secrets.token_urlsafe(32)
    refresh_token = secrets.token_urlsafe(32)
    row = Session(
        user_id=user.id,
        access_token_hash=hash_token(access_token),
        refresh_token_hash=hash_token(refresh_token),
        device_label=device_label,
        expires_at=datetime.now(UTC) + ACCESS_TOKEN_TTL,
    )
    session.add(row)
    return access_token, refresh_token, row


def tokens_out(user: User, access_token: str, refresh_token: str) -> AuthTokensOut:
    return AuthTokensOut(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=int(ACCESS_TOKEN_TTL.total_seconds()),
        user_id=user.id,
        nickname=user.nickname,
    )


async def _upsert_apple_user(
    session: AsyncSession,
    *,
    apple_sub: str,
    nickname: str | None,
) -> User:
    result = await session.scalars(
        select(AppleIdentity)
        .where(AppleIdentity.apple_sub == apple_sub)
        .options(selectinload(AppleIdentity.user))
    )
    identity = result.first()
    if identity is None:
        user = User(nickname=(nickname or "夜行者").strip() or "夜行者")
        session.add(user)
        await session.flush()
        session.add(AppleIdentity(user_id=user.id, apple_sub=apple_sub))
        session.add(UserSettings(user_id=user.id, default_scene_id=DEFAULT_SCENE_ID))
        return user

    user = identity.user
    if nickname:
        user.nickname = nickname.strip() or user.nickname
    return user


async def authenticate_apple(
    session: AsyncSession,
    *,
    identity_token: str,
    nickname: str | None,
    device_label: str | None,
    nonce: str | None = None,
) -> AuthTokensOut:
    """Verify Sign in with Apple identity token (JWKS) and issue app session tokens.

    In development (or when ``DW_ALLOW_DEV_APPLE_AUTH=true``), ``dev:<apple_sub>``
    remains accepted for local smoke tests without a real Apple JWT.
    """
    settings = get_settings()
    dev_sub = parse_dev_apple_sub(identity_token)
    if dev_sub is not None:
        if not settings.dev_apple_auth_enabled:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Dev Apple auth is disabled",
            )
        apple_sub = dev_sub
    else:
        claims = await verify_apple_identity_token(
            identity_token,
            nonce=nonce,
            settings=settings,
        )
        apple_sub = claims.sub

    user = await _upsert_apple_user(session, apple_sub=apple_sub, nickname=nickname)
    access_token, refresh_token, _ = _issue_tokens(session, user, device_label=device_label)
    from app.services import audit as audit_service

    await audit_service.record_audit(
        session,
        action="auth.login",
        user_id=user.id,
        resource_type="session",
        detail={"provider": "apple", "dev": dev_sub is not None},
    )
    await session.commit()
    return tokens_out(user, access_token, refresh_token)


# Backward-compatible alias used by older call sites / docs.
authenticate_apple_dev = authenticate_apple


async def resolve_user_by_access_token(session: AsyncSession, access_token: str) -> User:
    token_hash = hash_token(access_token)
    result = await session.scalars(
        select(Session)
        .where(Session.access_token_hash == token_hash)
        .options(selectinload(Session.user))
    )
    row = result.first()
    now = datetime.now(UTC)
    if row is None or row.revoked_at is not None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired access token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    expires = row.expires_at
    if expires.tzinfo is None:
        expires = expires.replace(tzinfo=UTC)
    if expires <= now:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired access token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    if row.user.status != "active":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="User inactive")
    return row.user


async def refresh_session(session: AsyncSession, refresh_token: str) -> AuthTokensOut:
    token_hash = hash_token(refresh_token)
    result = await session.scalars(
        select(Session)
        .where(Session.refresh_token_hash == token_hash)
        .options(selectinload(Session.user))
    )
    row = result.first()
    now = datetime.now(UTC)
    if row is None or row.revoked_at is not None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token",
        )
    # Allow refresh up to REFRESH_TOKEN_TTL after session creation.
    created = row.created_at
    if created.tzinfo is None:
        created = created.replace(tzinfo=UTC)
    if created + REFRESH_TOKEN_TTL < now:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token expired",
        )
    row.revoked_at = now
    access_token, new_refresh, _ = _issue_tokens(
        session, row.user, device_label=row.device_label
    )
    await session.commit()
    return tokens_out(row.user, access_token, new_refresh)


async def logout(session: AsyncSession, access_token: str) -> uuid.UUID | None:
    token_hash = hash_token(access_token)
    result = await session.scalars(select(Session).where(Session.access_token_hash == token_hash))
    row = result.first()
    if row is not None and row.revoked_at is None:
        user_id = row.user_id
        row.revoked_at = datetime.now(UTC)
        from app.services import audit as audit_service

        await audit_service.record_audit(
            session,
            action="auth.logout",
            user_id=user_id,
            resource_type="session",
            resource_id=row.id,
        )
        await session.commit()
        return user_id
    return None


async def get_user(session: AsyncSession, user_id: uuid.UUID) -> User | None:
    return await session.get(User, user_id)
