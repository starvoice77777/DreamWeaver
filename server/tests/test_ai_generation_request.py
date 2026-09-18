import copy
import json
from pathlib import Path

import pytest

from app.schemas.ai_generation import GenerationRequestError, validate_generation_request

_EXAMPLE = Path(__file__).parent / "fixtures" / "ai_generation_request_boundary_rain.json"


@pytest.fixture
def request_data():
    return json.loads(_EXAMPLE.read_text(encoding="utf-8"))


def test_product_example_preserves_values_and_does_not_alias_input(request_data):
    original = copy.deepcopy(request_data)
    result = validate_generation_request(request_data)
    assert result == original
    result["selected_sounds"][0]["user_locked"] = False
    assert request_data == original


def test_optional_fields_stay_absent_and_required_fields_cannot_be_omitted(request_data):
    required = ("contract_version", "request_id", "idempotency_key", "generation_mode",
                "user_context", "framework", "selected_sounds")
    minimal = {key: request_data[key] for key in required}
    assert validate_generation_request(minimal) == minimal
    for key in required:
        incomplete = {name: value for name, value in minimal.items() if name != key}
        with pytest.raises(GenerationRequestError):
            validate_generation_request(incomplete)


@pytest.mark.parametrize("framework,state", [
    ("boundary_gate", {"boundary_openness": 0}),
    ("boundary_gate", {"boundary_openness": 1}),
    ("enclosure_control", {"enclosure_level": "enclosed"}),
    ("depth_reveal", {"depth_reveal": "far"}),
    ("focus_selector", {"focus_target": "sound-rain"}),
    ("nearfield_width", {"nearfield_width": "wide"}),
])
def test_framework_accepts_its_state_and_rejects_mismatched_state(request_data, framework, state):
    request_data["framework"] = {"framework_id": framework, "state": state}
    validate_generation_request(request_data)
    request_data["framework"]["state"] = {"unknown_state": "wide"}
    with pytest.raises(GenerationRequestError):
        validate_generation_request(request_data)


@pytest.mark.parametrize("path,value,code", [
    (("selected_sounds",), [], "INVALID_REQUEST"),
    (("user_context", "primary_goal"), "medical_sleep", "UNKNOWN_GOAL"),
    (("framework", "framework_id"), "free_canvas", "UNKNOWN_FRAMEWORK"),
    (("framework", "state", "boundary_openness"), 1.1, "INVALID_REQUEST"),
    (("framework", "state", "boundary_openness"), True, "INVALID_REQUEST"),
    (("generation_mode",), "adjustment", "INVALID_REQUEST"),
    (("optional_instruction",), "私" * 501, "INVALID_REQUEST"),
    (("optional_instruction",), None, "INVALID_REQUEST"),
    (("idempotency_key",), "short", "INVALID_REQUEST"),
    (("random_seed",), -1, "INVALID_REQUEST"),
    (("random_seed",), float("nan"), "INVALID_REQUEST"),
    (("random_seed",), float("inf"), "INVALID_REQUEST"),
    (("user_context", "state_tags"), ["tense", "tense"], "INVALID_REQUEST"),
    (("user_context", "preferred_duration_seconds"), 59, "INVALID_REQUEST"),
    (("selected_sounds", 0, "user_locked"), "true", "INVALID_REQUEST"),
    (("selected_sounds", 0, "resource_key"), "../rain", "INVALID_REQUEST"),
    (("selected_sounds", 0, "binding_status"), "approved", "INVALID_REQUEST"),
    (("excluded_resource_keys",), ["rain", "rain"], "INVALID_REQUEST"),
    (("unknown_field",), "private instruction", "INVALID_REQUEST"),
])
def test_invalid_requests_fail_without_echoing_values(request_data, path, value, code):
    target = request_data
    for part in path[:-1]:
        target = target[part]
    target[path[-1]] = value
    with pytest.raises(GenerationRequestError) as caught:
        validate_generation_request(request_data)
    assert caught.value.code == code
    assert "私" not in str(caught.value)
    assert "private instruction" not in str(caught.value)


def test_sound_count_and_duplicate_ids_are_separate_gates(request_data):
    sound = request_data["selected_sounds"][0]
    request_data["selected_sounds"] = [dict(sound, sound_object_id=f"sound-{i}") for i in range(4)]
    validate_generation_request(request_data)
    request_data["selected_sounds"].append(dict(sound))
    with pytest.raises(GenerationRequestError, match="TOO_MANY_SOUND_OBJECTS"):
        validate_generation_request(request_data)
    request_data["selected_sounds"] = [dict(sound), dict(sound)]
    with pytest.raises(GenerationRequestError, match="duplicate sound_object_id"):
        validate_generation_request(request_data)


def test_adjustment_requires_positive_version_and_unique_manual_overrides(request_data):
    request_data["generation_mode"] = "adjustment"
    request_data["source_scene"] = {"scene_id": "scene-1", "timeline_version": 1,
                                    "manual_override_track_ids": ["track-1"]}
    validate_generation_request(request_data)
    request_data["source_scene"]["timeline_version"] = 0
    with pytest.raises(GenerationRequestError):
        validate_generation_request(request_data)
    request_data["source_scene"]["timeline_version"] = 1
    request_data["source_scene"]["manual_override_track_ids"] *= 2
    with pytest.raises(GenerationRequestError):
        validate_generation_request(request_data)
