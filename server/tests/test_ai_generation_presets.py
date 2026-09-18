import copy
import json
from dataclasses import replace
from pathlib import Path

import pytest

from app.schemas.ai_generation import GenerationRequestError
from app.services.ai_generation_bindings import (
    AssetCatalog,
    BindingGateError,
    CatalogAsset,
    FrameBinding,
    FrameBindingIndex,
)
from app.services.ai_generation_presets import (
    ContentPreset,
    ContentPresetError,
    ContentPresetRegistry,
    resolve_content_presets,
)


@pytest.fixture
def preset_case():
    # Synthetic approvals only; handoff presets remain draft.
    payload = json.loads((Path(__file__).parent / "fixtures" /
                          "ai_generation_request_boundary_rain.json").read_text(encoding="utf-8"))
    preset = ContentPreset("rain_sleep_onset", "fixture-p1", "approved",
                           frozenset({"boundary_gate"}), frozenset({"sleep_onset"}),
                           frozenset({"tired_but_alert", "needs_masking", "fixture_extra"}))
    asset = CatalogAsset("fixture_rain_main_soft", "master", "approved", "approved")
    binding = FrameBinding("fixture-binding", "fixture-b1", asset.resource_key,
                           "boundary_gate", "outside", "approved",
                           frozenset({preset.content_preset_id, "fixture_alternative"}))
    return payload, dict(catalog=AssetCatalog("fixture-c1", (asset,)),
                         binding_index=FrameBindingIndex("fixture-i1", (binding,)),
                         registry=ContentPresetRegistry("fixture-r1", (preset,)))


@pytest.mark.parametrize("explicit", [True, False])
def test_unique_resolution_preserves_request_and_dependency_versions(preset_case, explicit):
    payload, deps = preset_case
    if not explicit:
        del payload["content_preset_id"]
    original = copy.deepcopy(payload)
    result = resolve_content_presets(payload, **deps)
    assert result == resolve_content_presets(payload, **deps)
    assert result.selected_preset == result.candidates[0] == deps["registry"].presets[0]
    assert (result.registry_version, result.selected_preset.version,
            result.selection.catalog_version, result.selection.binding_index_version) == (
                "fixture-r1", "fixture-p1", "fixture-c1", "fixture-i1")
    assert result.selection.request == original
    result.selection.request["selected_sounds"][0]["user_locked"] = False
    assert payload == original
    deps["registry"] = replace(deps["registry"], version="fixture-r2")
    assert resolve_content_presets(payload, **deps).registry_version == "fixture-r2"


@pytest.mark.parametrize("field,value,reason", [
    *(('status', status, 'PRESET_NOT_APPROVED') for status in
      ("draft", "listening", "rejected", "unknown", "")),
    ("version", " ", "INCOMPLETE_PRESET"),
    ("primary_goals", frozenset({"stress_recovery"}), "PRESET_GOAL_MISMATCH"),
    ("framework_ids", frozenset({"nearfield_width"}), "PRESET_FRAMEWORK_MISMATCH"),
    ("allowed_state_tags", frozenset({"tired_but_alert"}), "PRESET_STATE_MISMATCH"),
    ("allowed_state_tags", frozenset(), "PRESET_STATE_MISMATCH"),
])
@pytest.mark.parametrize("explicit", [True, False])
def test_incompatible_presets_fail_without_echoing_user_values(
    preset_case, field, value, reason, explicit
):
    payload, deps = preset_case
    if not explicit:
        del payload["content_preset_id"]
    registry = deps["registry"]
    deps["registry"] = replace(registry, presets=(replace(registry.presets[0], **{field: value}),))
    with pytest.raises(ContentPresetError) as caught:
        resolve_content_presets(payload, **deps)
    assert caught.value.code == "INCOMPATIBLE_CONTENT_PRESET"
    assert caught.value.reason_code == (reason if explicit else "NO_COMPATIBLE_PRESET")
    assert caught.value.path == ("content_preset_id",)
    assert "rain_sleep_onset" not in str(caught.value)
    assert payload["optional_instruction"] not in str(caught.value)


@pytest.mark.parametrize("case,reason", [
    ("version", "MISSING_PRESET_REGISTRY_VERSION"), ("unknown", "UNKNOWN_CONTENT_PRESET"),
    ("duplicate", "AMBIGUOUS_PRESET_ID"), ("empty", "NO_COMPATIBLE_PRESET"),
])
def test_missing_or_ambiguous_registry_never_guesses(preset_case, case, reason):
    payload, deps = preset_case
    registry = deps["registry"]
    if case == "version":
        deps["registry"] = replace(registry, version=" ")
    elif case == "unknown":
        payload["content_preset_id"] = "fixture_unknown"
    elif case == "duplicate":
        deps["registry"] = replace(registry, presets=(*registry.presets,
                                   replace(registry.presets[0], status="draft")))
    else:
        del payload["content_preset_id"]
        deps["registry"] = replace(registry, presets=())
    with pytest.raises(ContentPresetError, match=reason):
        resolve_content_presets(payload, **deps)


def test_ambiguity_is_stable_and_explicit_choice_is_preserved(preset_case):
    payload, deps = preset_case
    registry = deps["registry"]
    alternative = replace(registry.presets[0], content_preset_id="fixture_alternative")
    rejected = replace(alternative, content_preset_id="fixture_draft", status="draft")
    deps["registry"] = replace(registry, presets=(*registry.presets, alternative, rejected))
    assert resolve_content_presets(payload, **deps).selected_preset == registry.presets[0]
    del payload["content_preset_id"]
    result = resolve_content_presets(payload, **deps)
    assert result.selected_preset is None
    assert [p.content_preset_id for p in result.candidates] == [
        "fixture_alternative", "rain_sleep_onset"]
    deps["registry"] = replace(deps["registry"], presets=tuple(reversed(deps["registry"].presets)))
    assert result == resolve_content_presets(payload, **deps)


@pytest.mark.parametrize("explicit", [True, False])
@pytest.mark.parametrize("locked", [True, False])
def test_every_sound_must_allow_preset_even_when_unlocked(preset_case, explicit, locked):
    payload, deps = preset_case
    if not explicit:
        del payload["content_preset_id"]
    payload["selected_sounds"].append({"sound_object_id": "room", "resource_key": "fixture_room",
                                       "user_locked": locked})
    catalog, index = deps["catalog"], deps["binding_index"]
    deps["catalog"] = replace(catalog, assets=(*catalog.assets,
                              replace(catalog.assets[0], resource_key="fixture_room")))
    room = replace(index.bindings[0], binding_id="fixture-room", resource_key="fixture_room",
                   allowed_content_presets=frozenset())
    deps["binding_index"] = replace(index, bindings=(*index.bindings, room))
    with pytest.raises(ContentPresetError):
        resolve_content_presets(payload, **deps)
    room = replace(room, allowed_content_presets=frozenset({"rain_sleep_onset"}))
    deps["binding_index"] = replace(index, bindings=(*index.bindings, room))
    result = resolve_content_presets(payload, **deps)
    assert result.selected_preset.content_preset_id == "rain_sleep_onset"
    assert result.selection.request == payload


def test_request_and_binding_gates_cannot_be_bypassed(preset_case):
    payload, deps = preset_case
    payload["excluded_resource_keys"].append(payload["selected_sounds"][0]["resource_key"])
    with pytest.raises(BindingGateError, match="SELECTED_RESOURCE_EXCLUDED"):
        resolve_content_presets(payload, **deps)
    payload["selected_sounds"] = []
    with pytest.raises(GenerationRequestError, match="INVALID_REQUEST"):
        resolve_content_presets(payload, **deps)
