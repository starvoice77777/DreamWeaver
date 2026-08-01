from __future__ import annotations

import uuid
from datetime import UTC
from pathlib import PurePosixPath

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.models.library import UploadSession, UserSoundAsset
from app.models.user import PrivateScene, User
from app.schemas.library import (
    ALLOWED_CONTENT_TYPES,
    ALLOWED_EXTENSIONS,
    ALLOWED_KINDS,
    AffectedSceneOut,
    DeleteAssetOut,
    DeleteImpactOut,
    PlaybackUrlOut,
    SoundAssetOut,
    SoundAssetPatch,
    UploadCreate,
    UploadSessionOut,
    expires_in,
    utc_now,
)
from app.services.storage import ObjectStorage, get_object_storage


def _extension(filename: str) -> str:
    suffix = PurePosixPath(filename).suffix.lower().lstrip(".")
    return suffix


def _validate_create(body: UploadCreate, settings: Settings) -> str:
    ext = _extension(body.filename)
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=f"Unsupported extension .{ext}; allowed: {sorted(ALLOWED_EXTENSIONS)}",
        )
    content_type = body.content_type.strip().lower()
    if content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=f"Unsupported content_type {body.content_type}",
        )
    if body.byte_size > settings.upload_max_bytes:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=f"byte_size exceeds limit {settings.upload_max_bytes}",
        )
    kind = body.kind.strip().lower()
    if kind not in ALLOWED_KINDS:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=f"Unsupported kind {body.kind}",
        )
    return ext


def asset_to_out(row: UserSoundAsset) -> SoundAssetOut:
    return SoundAssetOut(
        id=row.id,
        name=row.name,
        kind=row.kind,
        symbol_name=row.symbol_name,
        duration_seconds=row.duration_seconds,
        content_type=row.content_type,
        byte_size=row.byte_size,
        is_favorite=row.is_favorite,
        processing_status=row.processing_status,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


async def create_upload(
    session: AsyncSession,
    user: User,
    body: UploadCreate,
    *,
    storage: ObjectStorage | None = None,
    settings: Settings | None = None,
) -> UploadSessionOut:
    settings = settings or get_settings()
    storage = storage or get_object_storage()
    ext = _validate_create(body, settings)
    upload_id = uuid.uuid4()
    storage_key = f"uploads/{user.id}/{upload_id}/source.{ext}"
    display_name = (body.name or PurePosixPath(body.filename).stem or "未命名").strip()[:128]
    expires_at = expires_in(settings.upload_url_expires_seconds)

    row = UploadSession(
        id=upload_id,
        user_id=user.id,
        storage_key=storage_key,
        filename=body.filename,
        content_type=body.content_type.strip().lower(),
        declared_byte_size=body.byte_size,
        kind=body.kind.strip().lower(),
        display_name=display_name,
        status="pending",
        expires_at=expires_at,
    )
    session.add(row)
    await session.commit()
    await session.refresh(row)

    put_url = storage.presign_put(storage_key, settings.upload_url_expires_seconds)
    return UploadSessionOut(
        upload_id=row.id,
        put_url=put_url,
        storage_key=storage_key,
        required_headers={"Content-Type": row.content_type},
        expires_at=expires_at,
        max_byte_size=settings.upload_max_bytes,
    )


async def complete_upload(
    session: AsyncSession,
    user: User,
    upload_id: uuid.UUID,
    *,
    duration_seconds: int = 0,
    storage: ObjectStorage | None = None,
    settings: Settings | None = None,
) -> SoundAssetOut:
    settings = settings or get_settings()
    storage = storage or get_object_storage()

    result = await session.scalars(
        select(UploadSession).where(UploadSession.id == upload_id, UploadSession.user_id == user.id)
    )
    row = result.first()
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Upload not found")
    if row.status == "completed":
        existing = await session.scalars(
            select(UserSoundAsset).where(UserSoundAsset.upload_id == row.id)
        )
        asset = existing.first()
        if asset is None:
            raise HTTPException(status_code=500, detail="Completed upload missing asset")
        return asset_to_out(asset)
    if row.status != "pending":
        raise HTTPException(status_code=409, detail=f"Upload status is {row.status}")
    if row.expires_at.tzinfo is None:
        expired = row.expires_at.replace(tzinfo=UTC) < utc_now()
    else:
        expired = row.expires_at < utc_now()
    if expired:
        row.status = "expired"
        await session.commit()
        raise HTTPException(status_code=410, detail="Upload session expired")

    try:
        stat = storage.stat(row.storage_key)
    except FileNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Object not found in storage; upload the file before complete",
        ) from exc

    if stat.size <= 0:
        raise HTTPException(status_code=400, detail="Uploaded object is empty")
    if stat.size > settings.upload_max_bytes:
        raise HTTPException(status_code=400, detail="Uploaded object exceeds size limit")
    if stat.size > row.declared_byte_size * 1.05 + 1024:
        # Allow small overhead vs declared size, reject large mismatches.
        raise HTTPException(
            status_code=400,
            detail="Uploaded size does not match declared byte_size",
        )
    if stat.content_type and stat.content_type.lower() not in ALLOWED_CONTENT_TYPES:
        # Some clients omit or alter Content-Type; prefer declared when storage has none.
        if row.content_type not in ALLOWED_CONTENT_TYPES:
            raise HTTPException(status_code=400, detail="Uploaded content_type not allowed")

    asset = UserSoundAsset(
        owner_user_id=user.id,
        upload_id=row.id,
        name=row.display_name,
        kind=row.kind,
        symbol_name="waveform",
        duration_seconds=max(duration_seconds, 0),
        content_type=row.content_type,
        byte_size=stat.size,
        storage_key=row.storage_key,
        processing_status="ready",
    )
    row.status = "completed"
    row.completed_at = utc_now()
    session.add(asset)
    await session.commit()
    await session.refresh(asset)
    return asset_to_out(asset)


async def list_assets(session: AsyncSession, user: User) -> list[SoundAssetOut]:
    result = await session.scalars(
        select(UserSoundAsset)
        .where(
            UserSoundAsset.owner_user_id == user.id,
            UserSoundAsset.deleted_at.is_(None),
        )
        .order_by(UserSoundAsset.created_at.desc())
    )
    return [asset_to_out(row) for row in result.all()]


async def playback_url(
    session: AsyncSession,
    user: User,
    asset_id: uuid.UUID,
    *,
    storage: ObjectStorage | None = None,
    settings: Settings | None = None,
) -> PlaybackUrlOut:
    settings = settings or get_settings()
    storage = storage or get_object_storage()
    asset = await _owned_asset(session, user, asset_id)
    expires_at = expires_in(settings.playback_url_expires_seconds)
    url = storage.presign_get(asset.storage_key, settings.playback_url_expires_seconds)
    return PlaybackUrlOut(asset_id=asset.id, url=url, expires_at=expires_at)


async def _owned_asset(session: AsyncSession, user: User, asset_id: uuid.UUID) -> UserSoundAsset:
    result = await session.scalars(
        select(UserSoundAsset).where(
            UserSoundAsset.id == asset_id,
            UserSoundAsset.owner_user_id == user.id,
            UserSoundAsset.deleted_at.is_(None),
        )
    )
    asset = result.first()
    if asset is None:
        raise HTTPException(status_code=404, detail="Asset not found")
    return asset


def _source_asset_id(source: object) -> str | None:
    if not isinstance(source, dict):
        return None
    raw = source.get("assetId")
    if raw is None:
        raw = source.get("asset_id")
    if raw is None:
        return None
    return str(raw).lower()


def _count_asset_refs(sources: list | None, asset_id: uuid.UUID) -> int:
    needle = str(asset_id).lower()
    return sum(1 for item in (sources or []) if _source_asset_id(item) == needle)


def _scrub_asset_refs(sources: list | None, asset_id: uuid.UUID) -> list:
    needle = str(asset_id).lower()
    return [item for item in (sources or []) if _source_asset_id(item) != needle]


async def patch_asset(
    session: AsyncSession,
    user: User,
    asset_id: uuid.UUID,
    body: SoundAssetPatch,
) -> SoundAssetOut:
    asset = await _owned_asset(session, user, asset_id)
    data = body.model_dump(exclude_unset=True)
    if not data:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="No fields to update",
        )
    if "name" in data and data["name"] is not None:
        asset.name = data["name"].strip()[:128]
    if "symbol_name" in data and data["symbol_name"] is not None:
        asset.symbol_name = data["symbol_name"].strip()[:128]
    if "is_favorite" in data and data["is_favorite"] is not None:
        asset.is_favorite = bool(data["is_favorite"])
    asset.updated_at = utc_now()
    await session.commit()
    await session.refresh(asset)
    return asset_to_out(asset)


async def toggle_favorite(
    session: AsyncSession, user: User, asset_id: uuid.UUID
) -> SoundAssetOut:
    asset = await _owned_asset(session, user, asset_id)
    asset.is_favorite = not asset.is_favorite
    asset.updated_at = utc_now()
    await session.commit()
    await session.refresh(asset)
    return asset_to_out(asset)


async def delete_impact(
    session: AsyncSession, user: User, asset_id: uuid.UUID
) -> DeleteImpactOut:
    await _owned_asset(session, user, asset_id)
    result = await session.scalars(
        select(PrivateScene).where(
            PrivateScene.owner_user_id == user.id,
            PrivateScene.deleted_at.is_(None),
        )
    )
    affected: list[AffectedSceneOut] = []
    total = 0
    for scene in result.all():
        draft_count = _count_asset_refs(scene.draft_sources, asset_id)
        saved_count = _count_asset_refs(scene.saved_sources, asset_id)
        if draft_count or saved_count:
            total += draft_count + saved_count
            affected.append(
                AffectedSceneOut(
                    id=scene.id,
                    name=scene.name,
                    draft_reference_count=draft_count,
                    saved_reference_count=saved_count,
                )
            )
    return DeleteImpactOut(asset_id=asset_id, affected_scenes=affected, total_references=total)


async def delete_asset(
    session: AsyncSession,
    user: User,
    asset_id: uuid.UUID,
    *,
    storage: ObjectStorage | None = None,
) -> DeleteAssetOut:
    storage = storage or get_object_storage()
    asset = await _owned_asset(session, user, asset_id)
    storage_key = asset.storage_key
    preview_key = asset.preview_storage_key

    result = await session.scalars(
        select(PrivateScene).where(
            PrivateScene.owner_user_id == user.id,
            PrivateScene.deleted_at.is_(None),
        )
    )
    scrubbed: list[uuid.UUID] = []
    for scene in result.all():
        draft_before = list(scene.draft_sources or [])
        saved_before = list(scene.saved_sources or []) if scene.saved_sources is not None else None
        draft_after = _scrub_asset_refs(draft_before, asset_id)
        changed = len(draft_after) != len(draft_before)
        scene.draft_sources = draft_after
        if saved_before is not None:
            saved_after = _scrub_asset_refs(saved_before, asset_id)
            if len(saved_after) != len(saved_before):
                changed = True
            scene.saved_sources = saved_after
        if changed:
            scrubbed.append(scene.id)

    asset.deleted_at = utc_now()
    asset.updated_at = utc_now()
    await session.commit()

    storage_deleted = False
    try:
        storage.delete_object(storage_key)
        if preview_key:
            storage.delete_object(preview_key)
        storage_deleted = True
    except Exception:
        # Soft-delete already committed; object cleanup is best-effort.
        storage_deleted = False

    return DeleteAssetOut(
        asset_id=asset_id,
        deleted=True,
        scrubbed_scene_ids=scrubbed,
        storage_deleted=storage_deleted,
    )
