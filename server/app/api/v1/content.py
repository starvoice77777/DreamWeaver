from __future__ import annotations

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db_session
from app.schemas.content import (
    AppleAuthRequest,
    AuthTokensOut,
    BootstrapOut,
    MixPresetOut,
    SceneDetailOut,
    SceneSummaryOut,
)
from app.services import content as content_service

DbSession = Annotated[AsyncSession, Depends(get_db_session)]

router = APIRouter(tags=["content"])


@router.get("/bootstrap", response_model=BootstrapOut, summary="Cold-start payload")
async def bootstrap(session: DbSession) -> BootstrapOut:
    return await content_service.build_bootstrap(session)


@router.get("/scenes", response_model=list[SceneSummaryOut], summary="List published scenes")
async def list_scenes(session: DbSession) -> list[SceneSummaryOut]:
    return await content_service.list_scenes(session)


@router.get("/scenes/{scene_id}", response_model=SceneDetailOut, summary="Scene detail with tracks")
async def get_scene(scene_id: uuid.UUID, session: DbSession) -> SceneDetailOut:
    detail = await content_service.get_scene(session, scene_id)
    if detail is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Scene not found")
    return detail


@router.get(
    "/scenes/{scene_id}/presets",
    response_model=list[MixPresetOut],
    summary="Mix presets for a scene",
)
async def list_scene_presets(scene_id: uuid.UUID, session: DbSession) -> list[MixPresetOut]:
    detail = await content_service.get_scene(session, scene_id)
    if detail is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Scene not found")
    return await content_service.list_mix_presets(session, scene_id=scene_id)


@router.get("/presets", response_model=list[MixPresetOut], summary="List published mix presets")
async def list_presets(
    session: DbSession,
    scene_id: Annotated[uuid.UUID | None, Query()] = None,
) -> list[MixPresetOut]:
    return await content_service.list_mix_presets(session, scene_id=scene_id)


auth_router = APIRouter(prefix="/auth", tags=["auth"])


@auth_router.post("/apple", response_model=AuthTokensOut, summary="Sign in with Apple")
async def apple_sign_in(body: AppleAuthRequest, session: DbSession) -> AuthTokensOut:
    return await content_service.authenticate_apple_dev(
        session,
        identity_token=body.identity_token,
        nickname=body.nickname,
        device_label=body.device_label,
    )
