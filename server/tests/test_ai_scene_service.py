import json
import uuid

import pytest

from app.schemas.ai_scene import GenerateRequest, SceneAssistOptions, SelectedSourceIn
from app.services.ai_scene import (
    SceneAssistGenerationError,
    adjust_scene,
    generate_scene,
)
from app.services.deepseek import DeepSeekProviderError


def _request() -> GenerateRequest:
    return GenerateRequest(
        selected_sources=[
            SelectedSourceIn(
                source_id=uuid.UUID("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"),
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
        ],
        options=SceneAssistOptions(duration_seconds=30),
    )


class FakeClient:
    def __init__(self, responses):
        self.responses = iter(responses)
        self.calls = 0
        self.prompts = []

    async def complete(self, **kwargs):
        self.calls += 1
        self.prompts.append(kwargs.get("user_prompt", ""))
        return type("Completion", (), {"content": json.dumps(next(self.responses))})()


class ProviderErrorClient(FakeClient):
    async def complete(self, **kwargs):
        self.calls += 1
        self.prompts.append(kwargs.get("user_prompt", ""))
        raise DeepSeekProviderError("provider unavailable")


def _outline():
    return {
        "name": "Rain",
        "description": "A quiet rain scene",
        "theme": "rain",
        "use_case_tags": ["sleep"],
        "composition_profile": "environment_led",
        "foreground_priority": "environment",
        "trigger_focus": "none",
        "duration_policy": "asset_budgeted",
        "spatial_policy": "mostly_fixed",
        "trigger_mode": "none",
        "sections": [{"name": "main", "start_seconds": 0, "end_seconds": 30}],
    }


def _arrangement():
    return {
        "tracks": [{
            "resource_key": "rain_soft", "role": "bed", "start_seconds": 0,
            "end_seconds": 30, "loop": True, "default_volume": 0.3,
            "keyframes": [{"t": 0, "angle": 0, "radius": 0.8}],
        }]
    }


def _composition():
    return {
        "schema": "scene_composition_v2", "version": 2, "duration_seconds": 30,
        "source_groups": [{
            "id": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb", "name": "Rain",
            "layer": "environment", "position_keyframes": [{"t": 0, "angle": 0, "radius": 0.8}],
        }],
        "clips": [{
            "id": "cccccccc-cccc-cccc-cccc-cccccccccccc",
            "source_group_id": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
            "resource_key": "rain_soft", "start_seconds": 0, "end_seconds": 30,
            "source_offset_seconds": 0, "playback_mode": "loop", "crossfade_ms": 0,
        }],
    }


def _request_two():
    request = _request()
    request.selected_sources.append(
        SelectedSourceIn(
            source_id=uuid.UUID("dddddddd-dddd-dddd-dddd-dddddddddddd"),
            resource_key="fire_soft", name="Fire", description="Soft fire",
            layer="ambience", loop=True, duration_seconds=30,
            default_volume=0.2, angle=1, radius=0.7,
        )
    )
    return request


def _composition_two():
    value = _composition()
    value["source_groups"].append({
        "id": "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee", "name": "Fire",
        "layer": "ambience", "position_keyframes": [{"t": 0, "angle": 1, "radius": 0.7}],
    })
    value["clips"].append({
        "id": "ffffffff-ffff-ffff-ffff-ffffffffffff",
        "source_group_id": "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee",
        "resource_key": "fire_soft", "start_seconds": 5, "end_seconds": 10,
        "source_offset_seconds": 0, "playback_mode": "oneshot", "crossfade_ms": 0,
    })
    return value


@pytest.mark.asyncio
async def test_provider_error_is_not_repaired_or_retried():
    client = ProviderErrorClient([])
    with pytest.raises(DeepSeekProviderError):
        await generate_scene(client, _request())
    assert client.calls == 1
    assert len(client.prompts) == 1


@pytest.mark.asyncio
async def test_generate_scene_builds_valid_v2_and_retries_invalid_json():
    invalid = _composition()
    invalid["clips"][0]["crossfade_ms"] = 16000
    client = FakeClient([
        _outline(), _arrangement(),
        {"scene": {"name": "Rain"}, "composition": invalid},
        {"scene": {"name": "Rain"}, "composition": _composition()},
    ])
    result = await generate_scene(client, _request())
    assert result.composition["schema"] == "scene_composition_v2"
    assert result.composition["clips"][0]["resource_key"] == "rain_soft"
    assert client.calls == 4
    assert any("Validation error" in prompt for prompt in client.prompts)
    assert any("16000" in prompt for prompt in client.prompts)


@pytest.mark.asyncio
async def test_generate_scene_rejects_unknown_source():
    bad = _arrangement()
    bad["tracks"][0]["resource_key"] = "unknown"
    client = FakeClient([_outline(), bad, bad])
    with pytest.raises(SceneAssistGenerationError):
        await generate_scene(client, _request())


@pytest.mark.asyncio
async def test_arrangement_rejects_mismatched_source_id_and_resource_key():
    bad = _arrangement()
    bad["tracks"][0]["source_id"] = "dddddddd-dddd-dddd-dddd-dddddddddddd"
    client = FakeClient([_outline(), bad, bad])
    with pytest.raises(SceneAssistGenerationError):
        await generate_scene(client, _request())


@pytest.mark.asyncio
async def test_adjust_rejects_omitted_existing_source_after_repair():
    request = _request_two()
    omitted = _composition()
    client = FakeClient([
        {"scene": {"name": "Adjusted"}, "composition": omitted},
        {"scene": {"name": "Adjusted"}, "composition": omitted},
    ])
    from app.schemas.ai_scene import AdjustRequest

    with pytest.raises(SceneAssistGenerationError):
        await adjust_scene(client, AdjustRequest(
            selected_sources=request.selected_sources,
            scene={"composition": _composition_two()}, instruction="quieter",
        ))
    assert client.calls == 2


@pytest.mark.asyncio
async def test_adjust_rejects_swapped_source_bindings_with_same_ids():
    request = _request_two()
    existing = _composition_two()
    swapped = _composition_two()
    swapped["source_groups"][0]["name"] = "Fire"
    swapped["source_groups"][1]["name"] = "Rain"
    swapped["clips"][0]["resource_key"] = "fire_soft"
    swapped["clips"][1]["resource_key"] = "rain_soft"
    client = FakeClient([
        {"scene": {"name": "Adjusted"}, "composition": swapped},
        {"scene": {"name": "Adjusted"}, "composition": swapped},
    ])
    from app.schemas.ai_scene import AdjustRequest

    with pytest.raises(SceneAssistGenerationError):
        await adjust_scene(client, AdjustRequest(
            selected_sources=request.selected_sources,
            scene={"composition": existing}, instruction="quieter",
        ))
    assert client.calls == 2


@pytest.mark.asyncio
async def test_adjust_rejects_clip_source_mismatching_group():
    request = _request_two()
    mismatched = _composition()
    mismatched["clips"][0]["resource_key"] = "fire_soft"
    client = FakeClient([
        {"scene": {"name": "Adjusted"}, "composition": mismatched},
        {"scene": {"name": "Adjusted"}, "composition": mismatched},
    ])
    from app.schemas.ai_scene import AdjustRequest

    with pytest.raises(SceneAssistGenerationError):
        await adjust_scene(client, AdjustRequest(
            selected_sources=request.selected_sources,
            scene={"composition": _composition()}, instruction="quieter",
        ))


@pytest.mark.asyncio
async def test_adjust_returns_change_summary_and_complete_package():
    request = _request()
    from app.schemas.ai_scene import AdjustRequest

    client = FakeClient([{
        "scene": {"name": "Quieter rain"}, "composition": _composition(),
        "change_summary": ["Reduced rain volume"],
    }])
    result = await adjust_scene(client, AdjustRequest(
        selected_sources=request.selected_sources, scene={"composition": _composition()},
        instruction="make it quieter",
    ))
    assert result.change_summary == ["Reduced rain volume"]
    assert result.composition["clips"]
