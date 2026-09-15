from __future__ import annotations

import uuid

import pytest

from app.core.config import Settings
from app.schemas.ai_scene import (
    AdjustRequest,
    ArrangementPlan,
    ArrangementRequest,
    ArrangementTrack,
    CompileRequest,
    GenerateRequest,
    OutlineRequest,
    OutlineSection,
    SceneAdjustResult,
    SceneAssistOptions,
    SceneAssistResult,
    SceneOutline,
    SelectedSourceIn,
    SpatialKeyframe,
)
from app.services.ai_scene import SceneAssistGenerationError
from app.services.deepseek import DeepSeekProviderError

SOURCE_ID = uuid.UUID("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")


def source() -> SelectedSourceIn:
    return SelectedSourceIn(
        source_id=SOURCE_ID,
        resource_key="rain_soft",
        name="Rain",
        description="Soft rain",
        layer="environment",
        loop=True,
        duration_seconds=30,
        default_volume=0.3,
        angle=0,
        radius=0.8,
    )


def outline_result() -> SceneOutline:
    return SceneOutline(
        name="Rain",
        subtitle="Quiet rain",
        description="A quiet rain scene",
        theme="rain",
        use_case_tags=["sleep"],
        composition_profile="environment_led",
        foreground_priority="environment",
        trigger_focus="none",
        duration_policy="asset_budgeted",
        spatial_policy="mostly_fixed",
        trigger_mode="none",
        sections=[OutlineSection(name="main", start_seconds=0, end_seconds=30)],
    )


def arrangement_result() -> ArrangementPlan:
    return ArrangementPlan(
        tracks=[
            ArrangementTrack(
                source_id=SOURCE_ID,
                resource_key="rain_soft",
                role="bed",
                start_seconds=0,
                end_seconds=30,
                loop=True,
                default_volume=0.3,
                keyframes=[SpatialKeyframe(t=0, angle=0, radius=0.8)],
            )
        ]
    )


def composition() -> dict:
    return {
        "schema": "scene_composition_v2",
        "version": 2,
        "duration_seconds": 30,
        "source_groups": [],
        "clips": [],
    }


def result() -> SceneAssistResult:
    return SceneAssistResult(
        outline=outline_result(),
        arrangement=arrangement_result(),
        scene={"name": "Rain"},
        composition=composition(),
    )


class FakeClient:
    def __init__(self, *_args, **_kwargs) -> None:
        pass

    async def __aenter__(self) -> FakeClient:
        return self

    async def __aexit__(self, *_: object) -> None:
        return None


class ProviderFailureClient:
    entered = False
    exited = False

    def __init__(self, *_args, **_kwargs) -> None:
        type(self).entered = False
        type(self).exited = False

    async def __aenter__(self) -> ProviderFailureClient:
        type(self).entered = True
        return self

    async def __aexit__(self, *_: object) -> None:
        type(self).exited = True

    async def complete(self, **_kwargs):
        raise DeepSeekProviderError("provider unavailable")


async def auth_headers(client) -> dict[str, str]:
    response = await client.post(
        "/v1/auth/apple",
        json={"identity_token": "dev:ai-scene-api", "nickname": "AI"},
    )
    assert response.status_code == 200, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def outline_body() -> dict:
    return OutlineRequest(
        selected_sources=[source()], options=SceneAssistOptions(duration_seconds=30)
    ).model_dump(mode="json")


@pytest.mark.asyncio
async def test_ai_scene_requires_auth(client) -> None:
    response = await client.post("/v1/ai/scene-assist/outline", json=outline_body())
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_ai_scene_missing_key_returns_stable_503(client, monkeypatch) -> None:
    headers = await auth_headers(client)
    monkeypatch.setattr("app.api.v1.ai_scene.get_settings", lambda: Settings())
    response = await client.post(
        "/v1/ai/scene-assist/outline", headers=headers, json=outline_body()
    )
    assert response.status_code == 503
    assert response.json()["detail"] == {
        "code": "deepseek_configuration_error",
        "message": "DeepSeek API key is not configured",
    }


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "error", [DeepSeekProviderError("down"), SceneAssistGenerationError("invalid")]
)
async def test_ai_scene_failures_return_stable_502(client, monkeypatch, error) -> None:
    headers = await auth_headers(client)
    monkeypatch.setattr(
        "app.api.v1.ai_scene.get_settings",
        lambda: Settings(deepseek_api_key="test-key"),
    )
    monkeypatch.setattr("app.api.v1.ai_scene.DeepSeekClient", FakeClient)

    async def fail(*_args):
        raise error

    monkeypatch.setattr("app.api.v1.ai_scene.ai_scene_service.generate_outline", fail)
    response = await client.post(
        "/v1/ai/scene-assist/outline", headers=headers, json=outline_body()
    )
    assert response.status_code == 502
    assert response.json()["detail"]["code"] in {
        "deepseek_provider_error",
        "scene_assist_generation_error",
    }


@pytest.mark.asyncio
async def test_real_outline_maps_provider_error_and_closes_client(client, monkeypatch) -> None:
    headers = await auth_headers(client)
    monkeypatch.setattr(
        "app.api.v1.ai_scene.get_settings",
        lambda: Settings(deepseek_api_key="test-key"),
    )
    monkeypatch.setattr(
        "app.api.v1.ai_scene.DeepSeekClient", ProviderFailureClient
    )

    response = await client.post(
        "/v1/ai/scene-assist/outline", headers=headers, json=outline_body()
    )

    assert response.status_code == 502
    assert response.json()["detail"] == {
        "code": "deepseek_provider_error",
        "message": "DeepSeek provider request failed",
    }
    assert ProviderFailureClient.entered is True
    assert ProviderFailureClient.exited is True


@pytest.mark.asyncio
async def test_ai_scene_stage_and_combined_success_shapes(client, monkeypatch) -> None:
    headers = await auth_headers(client)
    monkeypatch.setattr(
        "app.api.v1.ai_scene.get_settings",
        lambda: Settings(deepseek_api_key="test-key"),
    )
    monkeypatch.setattr("app.api.v1.ai_scene.DeepSeekClient", FakeClient)
    monkeypatch.setattr(
        "app.api.v1.ai_scene.ai_scene_service.generate_outline",
        lambda *_: _async_value(outline_result()),
    )
    monkeypatch.setattr(
        "app.api.v1.ai_scene.ai_scene_service.generate_arrangement",
        lambda *_: _async_value(arrangement_result()),
    )
    monkeypatch.setattr(
        "app.api.v1.ai_scene.ai_scene_service.compile_scene",
        lambda *_: _async_value(result()),
    )
    monkeypatch.setattr(
        "app.api.v1.ai_scene.ai_scene_service.generate_scene",
        lambda *_: _async_value(result()),
    )
    monkeypatch.setattr(
        "app.api.v1.ai_scene.ai_scene_service.adjust_scene",
        lambda *_: _async_value(
            SceneAdjustResult(scene={"name": "Adjusted"}, composition=composition())
        ),
    )

    arrangement_body = ArrangementRequest(
        selected_sources=[source()], outline=outline_result()
    ).model_dump(mode="json")
    compile_body = CompileRequest(
        selected_sources=[source()], outline=outline_result(), arrangement=arrangement_result()
    ).model_dump(mode="json")
    generate_body = GenerateRequest(
        selected_sources=[source()], options=SceneAssistOptions(duration_seconds=30)
    ).model_dump(mode="json")
    adjust_body = AdjustRequest(
        selected_sources=[source()], scene={"name": "Rain"}, instruction="quieter"
    ).model_dump(mode="json")

    checks = [
        ("outline", outline_body(), "name", "Rain"),
        (
            "arrangement",
            arrangement_body,
            "tracks",
            [arrangement_result().model_dump(mode="json")["tracks"][0]],
        ),
        ("compile", compile_body, "composition", composition()),
        ("generate", generate_body, "scene", {"name": "Rain"}),
        ("adjust", adjust_body, "scene", {"name": "Adjusted"}),
    ]
    for path, body, key, expected in checks:
        response = await client.post(
            f"/v1/ai/scene-assist/{path}", headers=headers, json=body
        )
        assert response.status_code == 200, response.text
        assert response.json()[key] == expected


async def _async_value(value):
    return value
