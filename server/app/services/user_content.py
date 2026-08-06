from __future__ import annotations

import uuid
from datetime import UTC, datetime

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.content import Scene
from app.models.user import PrivateScene, User, UserSceneState, UserSettings
from app.schemas.content import (
    HomeOut,
    PrivateSceneCreate,
    PrivateSceneDetailOut,
    PrivateSceneDraftUpdate,
    PrivateSceneSummaryOut,
    SceneStateOut,
    SceneStatePatch,
    SceneSummaryOut,
    UserSettingsOut,
    UserSettingsUpdate,
)
from app.services.composition import CompositionValidationError, validate_composition
from app.services.content import list_scenes
from app.services.seed_catalog import DEFAULT_SCENE_ID, ensure_official_catalog


def _validated_composition_or_http(document: dict) -> dict:
    try:
        return validate_composition(document)
    except CompositionValidationError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=exc.as_detail(),
        ) from exc


DEFAULT_PALETTE = {
    "top": 0x1A2740,
    "mid": 0x2C3E55,
    "bottom": 0x1B1410,
    "accent": 0xD79A72,
}


def settings_to_out(row: UserSettings | None) -> UserSettingsOut:
    if row is None:
        return UserSettingsOut(default_scene_id=DEFAULT_SCENE_ID)
    return UserSettingsOut(
        reduce_motion=row.reduce_motion,
        auto_play_enabled=row.auto_play_enabled,
        background_play_enabled=row.background_play_enabled,
        lock_screen_play_enabled=row.lock_screen_play_enabled,
        animation_intensity=row.animation_intensity,
        dark_mode_forced=row.dark_mode_forced,
        audio_quality=row.audio_quality,
        notifications_enabled=row.notifications_enabled,
        default_scene_id=row.default_scene_id or DEFAULT_SCENE_ID,
    )


async def get_or_create_settings(session: AsyncSession, user: User) -> UserSettings:
    row = await session.get(UserSettings, user.id)
    if row is None:
        row = UserSettings(user_id=user.id, default_scene_id=DEFAULT_SCENE_ID)
        session.add(row)
        await session.flush()
    return row


async def update_settings(
    session: AsyncSession, user: User, body: UserSettingsUpdate
) -> UserSettingsOut:
    row = await get_or_create_settings(session, user)
    data = body.model_dump(exclude_unset=True)
    for key, value in data.items():
        setattr(row, key, value)
    await session.commit()
    await session.refresh(row)
    return settings_to_out(row)


async def _get_or_create_scene_state(
    session: AsyncSession, user_id: uuid.UUID, scene_id: uuid.UUID
) -> UserSceneState:
    row = await session.get(UserSceneState, (user_id, scene_id))
    if row is None:
        row = UserSceneState(user_id=user_id, scene_id=scene_id)
        session.add(row)
        await session.flush()
    return row


async def patch_scene_state(
    session: AsyncSession, user: User, scene_id: uuid.UUID, body: SceneStatePatch
) -> SceneStateOut:
    await ensure_official_catalog(session)
    scene = await session.scalar(
        select(Scene).where(Scene.id == scene_id, Scene.is_published.is_(True))
    )
    if scene is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Scene not found")

    row = await _get_or_create_scene_state(session, user.id, scene_id)
    if body.is_favorite is not None:
        row.is_favorite = body.is_favorite
    if body.mark_opened:
        row.last_opened_at = datetime.now(UTC)
        row.listen_count += 1
    await session.commit()
    await session.refresh(row)
    return SceneStateOut(
        scene_id=row.scene_id,
        is_favorite=row.is_favorite,
        last_opened_at=row.last_opened_at,
        listen_count=row.listen_count,
    )


async def build_home(session: AsyncSession, user: User) -> HomeOut:
    await ensure_official_catalog(session)
    scenes = await list_scenes(session)
    by_id = {item.id: item for item in scenes}

    states = (
        await session.scalars(select(UserSceneState).where(UserSceneState.user_id == user.id))
    ).all()
    favorites: list[SceneSummaryOut] = []
    recent: list[SceneSummaryOut] = []
    for state in sorted(
        [s for s in states if s.is_favorite],
        key=lambda s: s.updated_at,
        reverse=True,
    ):
        if state.scene_id in by_id:
            favorites.append(by_id[state.scene_id])
    for state in sorted(
        [s for s in states if s.last_opened_at is not None],
        key=lambda s: s.last_opened_at or datetime.min.replace(tzinfo=UTC),
        reverse=True,
    )[:8]:
        if state.scene_id in by_id:
            recent.append(by_id[state.scene_id])

    recommended = [item for item in scenes if item.is_demo_playable][:3] or scenes[:3]
    settings = settings_to_out(await session.get(UserSettings, user.id))
    return HomeOut(
        greeting_scene_id=settings.default_scene_id or DEFAULT_SCENE_ID,
        recommended=recommended,
        recent=recent,
        favorites=favorites,
        private_scenes=await list_private_scenes(session, user),
    )


def private_to_summary(scene: PrivateScene) -> PrivateSceneSummaryOut:
    return PrivateSceneSummaryOut(
        id=scene.id,
        name=scene.name,
        subtitle=scene.subtitle,
        description=scene.description,
        category=scene.category,
        tags=list(scene.tags or []),
        visual_style=scene.visual_style,
        source_scene_id=scene.source_scene_id,
        has_saved_version=scene.saved_sources is not None,
        saved_version=scene.saved_version,
        saved_at=scene.saved_at,
        updated_at=scene.updated_at,
    )


def private_to_detail(scene: PrivateScene) -> PrivateSceneDetailOut:
    summary = private_to_summary(scene)
    return PrivateSceneDetailOut(
        **summary.model_dump(),
        palette=scene.palette or DEFAULT_PALETTE,
        recommended_duration_seconds=scene.recommended_duration_seconds,
        draft_sources=list(scene.draft_sources or []),
        saved_sources=list(scene.saved_sources) if scene.saved_sources is not None else None,
        draft_timeline=dict(scene.draft_timeline) if scene.draft_timeline is not None else None,
        saved_timeline=dict(scene.saved_timeline) if scene.saved_timeline is not None else None,
        draft_composition=(
            dict(scene.draft_composition) if scene.draft_composition is not None else None
        ),
        saved_composition=(
            dict(scene.saved_composition) if scene.saved_composition is not None else None
        ),
    )


async def list_private_scenes(session: AsyncSession, user: User) -> list[PrivateSceneSummaryOut]:
    result = await session.scalars(
        select(PrivateScene)
        .where(PrivateScene.owner_user_id == user.id, PrivateScene.deleted_at.is_(None))
        .order_by(PrivateScene.updated_at.desc())
    )
    return [private_to_summary(item) for item in result.all()]


async def get_private_scene(
    session: AsyncSession, user: User, scene_id: uuid.UUID
) -> PrivateSceneDetailOut:
    scene = await _owned_private(session, user, scene_id)
    return private_to_detail(scene)


async def _owned_private(session: AsyncSession, user: User, scene_id: uuid.UUID) -> PrivateScene:
    scene = await session.get(PrivateScene, scene_id)
    if scene is None or scene.deleted_at is not None or scene.owner_user_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Private scene not found")
    return scene


def _tracks_as_sources(scene: Scene) -> list[dict]:
    return [
        {
            "name": track.name,
            "symbolName": track.symbol_name,
            "layer": track.layer,
            "initialEnvelope": track.initial_envelope,
            "position": {"angle": track.angle, "radius": track.radius},
            "resourceName": track.resource_key,
            "isEnabled": track.enabled_by_default,
        }
        for track in sorted(scene.tracks, key=lambda item: item.sort_order)
    ]


async def create_blank_private_scene(
    session: AsyncSession, user: User, body: PrivateSceneCreate
) -> PrivateSceneDetailOut:
    draft_composition = None
    if body.composition is not None:
        draft_composition = _validated_composition_or_http(body.composition)

    scene = PrivateScene(
        owner_user_id=user.id,
        name=body.name.strip() or "未命名场景",
        subtitle=body.subtitle or "",
        description=body.description or "",
        category=body.category or "personal",
        tags=list(body.tags or []),
        palette=body.palette or DEFAULT_PALETTE,
        visual_style=body.visual_style or "custom",
        draft_sources=list(body.sources or []),
        draft_timeline=dict(body.timeline) if body.timeline is not None else None,
        draft_composition=draft_composition,
    )
    session.add(scene)
    await session.commit()
    await session.refresh(scene)
    return private_to_detail(scene)


async def copy_official_scene(
    session: AsyncSession, user: User, scene_id: uuid.UUID
) -> PrivateSceneDetailOut:
    await ensure_official_catalog(session)
    result = await session.scalars(
        select(Scene)
        .where(Scene.id == scene_id, Scene.is_published.is_(True))
        .options(selectinload(Scene.tracks))
    )
    official = result.first()
    if official is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Scene not found")

    from app.services.timeline import get_timeline, timeline_document_dict

    official_timeline = await get_timeline(session, scene_id)
    draft_timeline = None
    if official_timeline is not None:
        doc = timeline_document_dict(official_timeline)
        # Snapshots belong to the private scene after copy; clear overrides.
        doc["manual_override_track_ids"] = []
        draft_timeline = doc

    scene = PrivateScene(
        owner_user_id=user.id,
        name=f"{official.name}（我的）",
        subtitle=official.subtitle,
        description=official.description,
        category=official.category,
        tags=list(official.tags or []),
        palette=dict(official.palette or DEFAULT_PALETTE),
        visual_style=official.visual_style,
        recommended_duration_seconds=official.recommended_duration_seconds,
        source_scene_id=official.id,
        draft_sources=_tracks_as_sources(official),
        draft_timeline=draft_timeline,
    )
    session.add(scene)
    await session.commit()
    await session.refresh(scene)
    return private_to_detail(scene)


async def update_private_draft(
    session: AsyncSession, user: User, scene_id: uuid.UUID, body: PrivateSceneDraftUpdate
) -> PrivateSceneDetailOut:
    scene = await _owned_private(session, user, scene_id)
    data = body.model_dump(exclude_unset=True)
    sources = data.pop("sources", None)
    draft_timeline = data.pop("draft_timeline", None)
    draft_composition = data.pop("draft_composition", None)
    for key, value in data.items():
        setattr(scene, key, value)
    if sources is not None:
        scene.draft_sources = sources
    if draft_timeline is not None:
        scene.draft_timeline = draft_timeline
    if draft_composition is not None:
        scene.draft_composition = _validated_composition_or_http(draft_composition)
    await session.commit()
    await session.refresh(scene)
    return private_to_detail(scene)


async def save_private_scene(
    session: AsyncSession, user: User, scene_id: uuid.UUID
) -> PrivateSceneDetailOut:
    scene = await _owned_private(session, user, scene_id)
    has_sources = bool(scene.draft_sources)
    has_composition = scene.draft_composition is not None
    if not has_sources and not has_composition:
        raise HTTPException(
            status_code=422,
            detail="Cannot save an empty mix; add at least one source or composition track",
        )
    if has_composition:
        scene.draft_composition = _validated_composition_or_http(scene.draft_composition)
        scene.saved_composition = dict(scene.draft_composition)
    else:
        scene.saved_composition = None
    scene.saved_sources = list(scene.draft_sources or [])
    scene.saved_timeline = (
        dict(scene.draft_timeline) if scene.draft_timeline is not None else None
    )
    scene.saved_version += 1
    scene.saved_at = datetime.now(UTC)
    await session.commit()
    await session.refresh(scene)
    return private_to_detail(scene)


async def delete_private_scene(session: AsyncSession, user: User, scene_id: uuid.UUID) -> None:
    scene = await _owned_private(session, user, scene_id)
    scene.deleted_at = datetime.now(UTC)
    await session.commit()
