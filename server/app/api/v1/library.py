from __future__ import annotations

import uuid
from typing import Annotated

from fastapi import APIRouter, Query

from app.api.deps import CurrentUser, DbSession
from app.schemas.library import (
    PlaybackUrlOut,
    SoundAssetOut,
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


@router.get(
    "/library/assets/{asset_id}/playback-url",
    response_model=PlaybackUrlOut,
    summary="Short-lived private playback URL",
)
async def playback_url(
    asset_id: uuid.UUID, session: DbSession, user: CurrentUser
) -> PlaybackUrlOut:
    return await library_service.playback_url(session, user, asset_id)
