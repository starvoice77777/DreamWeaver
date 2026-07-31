from __future__ import annotations

import hashlib
import secrets
import uuid
from datetime import UTC, datetime, timedelta

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.user import AppleIdentity, Session, User, UserSettings
from app.schemas.content import AuthTokensOut
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


async def authenticate_apple_dev(
    session: AsyncSession,
    *,
    identity_token: str,
    nickname: str | None,
    device_label: str | None,
) -> AuthTokensOut:
    """Development Apple auth.

    Production will verify the identity token with Apple JWKS.
    For local development, tokens may use the form ``dev:<apple_sub>``.
    """
    if identity_token.startswith("dev:"):
        apple_sub = identity_token.removeprefix("dev:").strip() or "dev-user"
    else:
        apple_sub = hash_token(identity_token)[:32]

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
        identity = AppleIdentity(user_id=user.id, apple_sub=apple_sub)
        session.add(identity)
        session.add(UserSettings(user_id=user.id, default_scene_id=DEFAULT_SCENE_ID))
    else:
        user = identity.user
        if nickname:
            user.nickname = nickname.strip() or user.nickname

    access_token, refresh_token, _ = _issue_tokens(session, user, device_label=device_label)
    await session.commit()
    return tokens_out(user, access_token, refresh_token)


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


async def logout(session: AsyncSession, access_token: str) -> None:
    token_hash = hash_token(access_token)
    result = await session.scalars(select(Session).where(Session.access_token_hash == token_hash))
    row = result.first()
    if row is not None and row.revoked_at is None:
        row.revoked_at = datetime.now(UTC)
        await session.commit()


async def get_user(session: AsyncSession, user_id: uuid.UUID) -> User | None:
    return await session.get(User, user_id)
