from __future__ import annotations

import hashlib
import secrets
import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.content import MixPreset, Scene
from app.models.user import AppleIdentity, Session, User, UserSettings
from app.schemas.content import (
    AuthTokensOut,
    BootstrapOut,
    MixPresetOut,
    SceneDetailOut,
    ScenePaletteOut,
    SceneSummaryOut,
    SceneTrackOut,
    SpatialPositionOut,
    UserSettingsOut,
)
from app.services.seed_catalog import DEFAULT_SCENE_ID, GREETINGS, ensure_official_catalog


def _hash_token(raw: str) -> str:
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def scene_to_summary(scene: Scene) -> SceneSummaryOut:
    palette = scene.palette or {}
    return SceneSummaryOut(
        id=scene.id,
        name=scene.name,
        subtitle=scene.subtitle,
        description=scene.description,
        category=scene.category,
        tags=list(scene.tags or []),
        palette=ScenePaletteOut(
            top=int(palette.get("top", 0x1A2740)),
            mid=int(palette.get("mid", 0x2C3E55)),
            bottom=int(palette.get("bottom", 0x1B1410)),
            accent=int(palette.get("accent", 0xD79A72)),
        ),
        visual_style=scene.visual_style,
        recommended_duration_seconds=scene.recommended_duration_seconds,
        is_demo_playable=scene.is_demo_playable,
        mock_listener_count=scene.mock_listener_count,
        sort_order=scene.sort_order,
    )


def scene_to_detail(scene: Scene) -> SceneDetailOut:
    summary = scene_to_summary(scene)
    tracks = [
        SceneTrackOut(
            id=track.id,
            name=track.name,
            symbol_name=track.symbol_name,
            layer=track.layer,
            volume=track.volume,
            position=SpatialPositionOut(angle=track.angle, radius=track.radius),
            resource_key=track.resource_key,
            loop=track.loop,
            enabled_by_default=track.enabled_by_default,
        )
        for track in sorted(scene.tracks, key=lambda item: item.sort_order)
    ]
    return SceneDetailOut(**summary.model_dump(), tracks=tracks)


async def list_scenes(session: AsyncSession) -> list[SceneSummaryOut]:
    await ensure_official_catalog(session)
    result = await session.scalars(
        select(Scene).where(Scene.is_published.is_(True)).order_by(Scene.sort_order, Scene.name)
    )
    return [scene_to_summary(scene) for scene in result.all()]


async def get_scene(session: AsyncSession, scene_id: uuid.UUID) -> SceneDetailOut | None:
    await ensure_official_catalog(session)
    result = await session.scalars(
        select(Scene)
        .where(Scene.id == scene_id, Scene.is_published.is_(True))
        .options(selectinload(Scene.tracks))
    )
    scene = result.first()
    if scene is None:
        return None
    return scene_to_detail(scene)


async def list_mix_presets(
    session: AsyncSession, scene_id: uuid.UUID | None = None
) -> list[MixPresetOut]:
    await ensure_official_catalog(session)
    stmt = select(MixPreset).where(MixPreset.is_published.is_(True)).order_by(MixPreset.sort_order)
    if scene_id is not None:
        stmt = stmt.where((MixPreset.scene_id == scene_id) | (MixPreset.scene_id.is_(None)))
    result = await session.scalars(stmt)
    return [
        MixPresetOut(
            id=preset.id,
            name=preset.name,
            style_hint=preset.style_hint,
            author_name=preset.author_name,
            sources=list(preset.sources or []),
            scene_id=preset.scene_id,
        )
        for preset in result.all()
    ]


async def build_bootstrap(session: AsyncSession, user: User | None = None) -> BootstrapOut:
    scenes = await list_scenes(session)
    settings_out = UserSettingsOut(default_scene_id=DEFAULT_SCENE_ID)
    if user is not None:
        result = await session.get(UserSettings, user.id)
        if result is not None:
            settings_out = UserSettingsOut(
                reduce_motion=result.reduce_motion,
                auto_play_enabled=result.auto_play_enabled,
                background_play_enabled=result.background_play_enabled,
                lock_screen_play_enabled=result.lock_screen_play_enabled,
                animation_intensity=result.animation_intensity,
                dark_mode_forced=result.dark_mode_forced,
                audio_quality=result.audio_quality,
                notifications_enabled=result.notifications_enabled,
                default_scene_id=result.default_scene_id or DEFAULT_SCENE_ID,
            )

    greeting_index = datetime.now(UTC).timetuple().tm_yday % len(GREETINGS)
    return BootstrapOut(
        greeting=GREETINGS[greeting_index],
        default_scene_id=settings_out.default_scene_id or DEFAULT_SCENE_ID,
        scenes=scenes,
        settings=settings_out,
        server_time=datetime.now(UTC),
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
        # Phase-2 placeholder until Apple JWKS verification lands.
        apple_sub = _hash_token(identity_token)[:32]

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

    access_token = secrets.token_urlsafe(32)
    refresh_token = secrets.token_urlsafe(32)
    expires_at = datetime.now(UTC) + timedelta(days=30)
    session.add(
        Session(
            user_id=user.id,
            access_token_hash=_hash_token(access_token),
            refresh_token_hash=_hash_token(refresh_token),
            device_label=device_label,
            expires_at=expires_at,
        )
    )
    await session.commit()

    return AuthTokensOut(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=30 * 24 * 60 * 60,
        user_id=user.id,
        nickname=user.nickname,
    )
