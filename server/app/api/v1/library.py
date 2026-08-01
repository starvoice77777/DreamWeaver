from __future__ import annotations

import uuid
from typing import Annotated

from fastapi import APIRouter, Query

from app.api.deps import CurrentUser, DbSession
from app.schemas.library import (
    DeleteAssetOut,
    DeleteImpactOut,
    PlaybackUrlOut,
    SoundAssetOut,
    SoundAssetPatch,
    UploadCreate,
    UploadSessionOut,
)
from app.services import library as library_service

router = APIRouter(tags=["library"])


@router.post("/uploads", response_model=UploadSessionOut, summary="Create presigned upload session")
async def create_upload(
    body: UploadCreate, session: DbSession, user: CurrentUser
) -> UploadSessionOut:
    return await library_service.create_upload(session, user, body)


@router.post(
    "/uploads/{upload_id}/complete",
    response_model=SoundAssetOut,
    summary="Confirm upload and create sound asset",
)
async def complete_upload(
    upload_id: uuid.UUID,
    session: DbSession,
    user: CurrentUser,
    duration_seconds: Annotated[int, Query(ge=0, le=86_400)] = 0,
) -> SoundAssetOut:
    return await library_service.complete_upload(
        session, user, upload_id, duration_seconds=duration_seconds
    )


@router.get(
    "/library/assets",
    response_model=list[SoundAssetOut],
    summary="List current user's sound assets",
)
async def list_assets(session: DbSession, user: CurrentUser) -> list[SoundAssetOut]:
    return await library_service.list_assets(session, user)


@router.patch(
    "/library/assets/{asset_id}",
    response_model=SoundAssetOut,
    summary="Update asset metadata (name / symbol / favorite)",
)
async def patch_asset(
    asset_id: uuid.UUID, body: SoundAssetPatch, session: DbSession, user: CurrentUser
) -> SoundAssetOut:
    return await library_service.patch_asset(session, user, asset_id, body)


@router.post(
    "/library/assets/{asset_id}/favorite",
    response_model=SoundAssetOut,
    summary="Toggle asset favorite flag",
)
async def toggle_favorite(
    asset_id: uuid.UUID, session: DbSession, user: CurrentUser
) -> SoundAssetOut:
    return await library_service.toggle_favorite(session, user, asset_id)


@router.get(
    "/library/assets/{asset_id}/delete-impact",
    response_model=DeleteImpactOut,
    summary="Scenes that reference this asset (for confirm UI)",
)
async def delete_impact(
    asset_id: uuid.UUID, session: DbSession, user: CurrentUser
) -> DeleteImpactOut:
    return await library_service.delete_impact(session, user, asset_id)


@router.delete(
    "/library/assets/{asset_id}",
    response_model=DeleteAssetOut,
    summary="Soft-delete asset, scrub private-scene refs, best-effort storage cleanup",
)
async def delete_asset(
    asset_id: uuid.UUID, session: DbSession, user: CurrentUser
) -> DeleteAssetOut:
    return await library_service.delete_asset(session, user, asset_id)


@router.get(
    "/library/assets/{asset_id}/playback-url",
    response_model=PlaybackUrlOut,
    summary="Short-lived private playback URL",
)
async def playback_url(
    asset_id: uuid.UUID, session: DbSession, user: CurrentUser
) -> PlaybackUrlOut:
    return await library_service.playback_url(session, user, asset_id)
