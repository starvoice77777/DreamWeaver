from __future__ import annotations

import uuid
from typing import Annotated

from fastapi import APIRouter, Header, HTTPException, Query, Response, status

from app.api.deps import CurrentUser, DbSession, OptionalUser, extract_bearer_token
from app.schemas.content import (
    AppleAuthRequest,
    AuthTokensOut,
    BootstrapOut,
    HomeOut,
    MixPresetOut,
    PrivateSceneCreate,
    PrivateSceneDetailOut,
    PrivateSceneDraftUpdate,
    PrivateSceneSummaryOut,
    RefreshRequest,
    SceneDetailOut,
    SceneStateOut,
    SceneStatePatch,
    SceneSummaryOut,
    UserSettingsOut,
    UserSettingsUpdate,
)
from app.services import auth as auth_service
from app.services import content as content_service
from app.services import user_content as user_content_service

router = APIRouter(tags=["content"])
users_router = APIRouter(prefix="/users/me", tags=["users"])
auth_router = APIRouter(prefix="/auth", tags=["auth"])


@router.get("/bootstrap", response_model=BootstrapOut, summary="Cold-start payload")
async def bootstrap(session: DbSession, user: OptionalUser) -> BootstrapOut:
    return await content_service.build_bootstrap(session, user=user)


@router.get("/home", response_model=HomeOut, summary="Tonight recommendations and recent use")
async def home(session: DbSession, user: CurrentUser) -> HomeOut:
    return await user_content_service.build_home(session, user)


@router.get("/scenes", response_model=list[SceneSummaryOut], summary="List published scenes")
async def list_scenes(session: DbSession) -> list[SceneSummaryOut]:
    return await content_service.list_scenes(session)


@router.get("/scenes/{scene_id}", response_model=SceneDetailOut, summary="Scene detail with tracks")
async def get_scene(scene_id: uuid.UUID, session: DbSession) -> SceneDetailOut:
    detail = await content_service.get_scene(session, scene_id)
    if detail is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Scene not found")
    return detail


@router.post(
    "/scenes/{scene_id}/copy",
    response_model=PrivateSceneDetailOut,
    summary="Copy official scene into a private draft",
)
async def copy_scene(
    scene_id: uuid.UUID, session: DbSession, user: CurrentUser
) -> PrivateSceneDetailOut:
    return await user_content_service.copy_official_scene(session, user, scene_id)


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


@auth_router.post("/apple", response_model=AuthTokensOut, summary="Sign in with Apple")
async def apple_sign_in(body: AppleAuthRequest, session: DbSession) -> AuthTokensOut:
    return await auth_service.authenticate_apple(
        session,
        identity_token=body.identity_token,
        nickname=body.nickname,
        device_label=body.device_label,
        nonce=body.nonce,
    )


@auth_router.post("/refresh", response_model=AuthTokensOut, summary="Rotate session tokens")
async def refresh(body: RefreshRequest, session: DbSession) -> AuthTokensOut:
    return await auth_service.refresh_session(session, body.refresh_token)


@auth_router.post(
    "/logout",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Revoke access session",
)
async def logout(
    session: DbSession,
    authorization: Annotated[str | None, Header()] = None,
) -> Response:
    token = extract_bearer_token(authorization)
    await auth_service.logout(session, token)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@users_router.get("/settings", response_model=UserSettingsOut, summary="Current user settings")
async def get_settings(session: DbSession, user: CurrentUser) -> UserSettingsOut:
    row = await user_content_service.get_or_create_settings(session, user)
    await session.commit()
    return user_content_service.settings_to_out(row)


@users_router.put("/settings", response_model=UserSettingsOut, summary="Update user settings")
async def put_settings(
    body: UserSettingsUpdate, session: DbSession, user: CurrentUser
) -> UserSettingsOut:
    return await user_content_service.update_settings(session, user, body)


@users_router.patch(
    "/scene-states/{scene_id}",
    response_model=SceneStateOut,
    summary="Update favorite / recent use for an official scene",
)
async def patch_scene_state(
    scene_id: uuid.UUID,
    body: SceneStatePatch,
    session: DbSession,
    user: CurrentUser,
) -> SceneStateOut:
    return await user_content_service.patch_scene_state(session, user, scene_id, body)


@users_router.get(
    "/scenes",
    response_model=list[PrivateSceneSummaryOut],
    summary="List private scenes",
)
async def list_my_scenes(session: DbSession, user: CurrentUser) -> list[PrivateSceneSummaryOut]:
    return await user_content_service.list_private_scenes(session, user)


@users_router.post(
    "/scenes",
    response_model=PrivateSceneDetailOut,
    summary="Create a blank private scene draft",
)
async def create_my_scene(
    body: PrivateSceneCreate, session: DbSession, user: CurrentUser
) -> PrivateSceneDetailOut:
    return await user_content_service.create_blank_private_scene(session, user, body)


@users_router.get(
    "/scenes/{scene_id}",
    response_model=PrivateSceneDetailOut,
    summary="Private scene detail",
)
async def get_my_scene(
    scene_id: uuid.UUID, session: DbSession, user: CurrentUser
) -> PrivateSceneDetailOut:
    return await user_content_service.get_private_scene(session, user, scene_id)


@users_router.put(
    "/scenes/{scene_id}/draft",
    response_model=PrivateSceneDetailOut,
    summary="Update private scene draft (does not publish)",
)
async def put_my_draft(
    scene_id: uuid.UUID,
    body: PrivateSceneDraftUpdate,
    session: DbSession,
    user: CurrentUser,
) -> PrivateSceneDetailOut:
    return await user_content_service.update_private_draft(session, user, scene_id, body)


@users_router.post(
    "/scenes/{scene_id}/save",
    response_model=PrivateSceneDetailOut,
    summary="Explicitly save draft as a reusable version",
)
async def save_my_scene(
    scene_id: uuid.UUID, session: DbSession, user: CurrentUser
) -> PrivateSceneDetailOut:
    return await user_content_service.save_private_scene(session, user, scene_id)


@users_router.delete(
    "/scenes/{scene_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Soft-delete a private scene",
)
async def delete_my_scene(scene_id: uuid.UUID, session: DbSession, user: CurrentUser) -> Response:
    await user_content_service.delete_private_scene(session, user, scene_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
