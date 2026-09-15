from __future__ import annotations

from collections.abc import Awaitable, Callable
from typing import Any

from fastapi import APIRouter, HTTPException, status

from app.api.deps import CurrentUser
from app.core.config import get_settings
from app.schemas.ai_scene import (
    AdjustRequest,
    ArrangementPlan,
    ArrangementRequest,
    CompileRequest,
    GenerateRequest,
    OutlineRequest,
    SceneAdjustResult,
    SceneAssistResult,
    SceneOutline,
)
from app.services import ai_scene as ai_scene_service
from app.services.deepseek import (
    DeepSeekClient,
    DeepSeekConfigurationError,
    DeepSeekProviderError,
)

router = APIRouter(prefix="/ai/scene-assist", tags=["ai-scene-assist"])

def _http_error(exc: Exception) -> HTTPException:
    if isinstance(exc, DeepSeekConfigurationError):
        return HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={
                "code": "deepseek_configuration_error",
                "message": "DeepSeek API key is not configured",
            },
        )
    if isinstance(exc, DeepSeekProviderError):
        return HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail={
                "code": "deepseek_provider_error",
                "message": "DeepSeek provider request failed",
            },
        )
    return HTTPException(
        status_code=status.HTTP_502_BAD_GATEWAY,
        detail={
            "code": "scene_assist_generation_error",
            "message": "Scene generation failed validation",
        },
    )


async def _call[T](
    operation: Callable[[DeepSeekClient, Any], Awaitable[T]],
    body: Any,
) -> T:
    settings = get_settings()
    if not settings.deepseek_api_key:
        raise _http_error(DeepSeekConfigurationError("missing key"))
    try:
        async with DeepSeekClient(settings) as client:
            return await operation(client, body)
    except (DeepSeekConfigurationError, DeepSeekProviderError) as exc:
        raise _http_error(exc) from exc
    except ai_scene_service.SceneAssistGenerationError as exc:
        raise _http_error(exc) from exc


@router.post("/outline", response_model=SceneOutline)
async def outline(body: OutlineRequest, user: CurrentUser) -> SceneOutline:
    _ = user
    return await _call(ai_scene_service.generate_outline, body)


@router.post("/arrangement", response_model=ArrangementPlan)
async def arrangement(body: ArrangementRequest, user: CurrentUser) -> ArrangementPlan:
    _ = user
    return await _call(ai_scene_service.generate_arrangement, body)


@router.post("/compile", response_model=SceneAssistResult)
async def compile_scene(body: CompileRequest, user: CurrentUser) -> SceneAssistResult:
    _ = user
    return await _call(ai_scene_service.compile_scene, body)


@router.post("/generate", response_model=SceneAssistResult)
async def generate(body: GenerateRequest, user: CurrentUser) -> SceneAssistResult:
    _ = user
    return await _call(ai_scene_service.generate_scene, body)


@router.post("/adjust", response_model=SceneAdjustResult)
async def adjust(body: AdjustRequest, user: CurrentUser) -> SceneAdjustResult:
    _ = user
    return await _call(ai_scene_service.adjust_scene, body)
