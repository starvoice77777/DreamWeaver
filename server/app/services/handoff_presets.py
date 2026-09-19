"""Opt-in review catalog; the fixture ships inside the standalone backend image."""

import json
import uuid
from functools import lru_cache
from pathlib import Path
from typing import Any, cast

from app.core.config import get_settings

FIREPLACE_SCENE_ID = uuid.UUID("a1111111-1111-4111-8111-11111111110d")
MIST_SCENE_ID = uuid.UUID("a1111111-1111-4111-8111-111111111104")
EAR_SCENE_ID = uuid.UUID("a1111111-1111-4111-8111-111111111113")
PAGE_SCENE_ID = uuid.UUID("a1111111-1111-4111-8111-111111111114")
REVIEW_ONLY_SCENE_IDS = frozenset({EAR_SCENE_ID, PAGE_SCENE_ID})
_FIXTURE_DIRECTORY = Path(__file__).resolve().parent.parent / "fixtures"
FIXTURES = {
    FIREPLACE_SCENE_ID: _FIXTURE_DIRECTORY / "handoff_fireplace_v4.json",
    MIST_SCENE_ID: _FIXTURE_DIRECTORY / "handoff_mist_v4.json",
    EAR_SCENE_ID: _FIXTURE_DIRECTORY / "handoff_ear_v4.json",
    PAGE_SCENE_ID: _FIXTURE_DIRECTORY / "handoff_page_v4.json",
}


@lru_cache
def _review_fixture(scene_id: uuid.UUID) -> dict[str, Any]:
    preset = cast(dict[str, Any], json.loads(FIXTURES[scene_id].read_text(encoding="utf-8")))
    try:
        release_ready = preset["releaseReady"]
        usage = preset["usage"]
        fixture_scene_id = uuid.UUID(preset["sceneID"])
        source_ids = [uuid.UUID(source["id"]) for source in preset["sources"]]
        resource_keys = [source["resourceName"] for source in preset["sources"]]
        timeline_scene_id = uuid.UUID(preset["timeline"]["scene_id"])
    except (KeyError, TypeError, ValueError) as error:
        raise ValueError(f"Invalid review fixture for {scene_id}") from error
    if (
        release_ready is not False
        or usage != "debug_review_only"
        or fixture_scene_id != scene_id
        or timeline_scene_id != scene_id
        or not source_ids
        or len(source_ids) != len(set(source_ids))
        or any(not isinstance(key, str) or not key for key in resource_keys)
    ):
        raise ValueError(f"Invalid review fixture for {scene_id}")
    return preset


def review_preset(scene_id: uuid.UUID) -> dict[str, Any] | None:
    if scene_id not in FIXTURES or not get_settings().handoff_review_presets_enabled:
        return None
    return _review_fixture(scene_id)


def _preset_tracks(preset: dict[str, Any]) -> list[dict[str, Any]]:
    return [
        {
            "id": uuid.UUID(source["id"]),
            "name": source["name"],
            "symbol_name": source["symbolName"],
            "layer": source["layer"],
            "initial_envelope": source["initialEnvelope"],
            "angle": source["position"]["angle"],
            "radius": source["position"]["radius"],
            "resource_key": source["resourceName"],
            "loop": source["resourceName"] in preset["loopCrossfades"],
            "enabled_by_default": source["isEnabled"],
            "sort_order": index,
        }
        for index, source in enumerate(preset["sources"])
    ]


def apply_review_preset(spec: dict[str, Any]) -> dict[str, Any]:
    if (preset := review_preset(spec["id"])) is None:
        return spec
    return {
        **spec,
        "name": preset["name"],
        "subtitle": preset["subtitle"],
        "description": preset["subtitle"],
        "tags": preset["tags"],
        "is_demo_playable": True,
        "recommended_duration_seconds": preset["timeline"]["duration_hint_seconds"],
        "tracks": _preset_tracks(preset),
    }


def review_only_scene_specs() -> list[dict[str, Any]]:
    """Build additive review scenes only while the environment gate is active."""
    appearances = (
        (
            EAR_SCENE_ID,
            {
                "top": 0x15131B,
                "mid": 0x282331,
                "bottom": 0x0B0A10,
                "accent": 0xB79BCB,
            },
            "emotionalFluid",
            15,
        ),
        (
            PAGE_SCENE_ID,
            {
                "top": 0x1A2230,
                "mid": 0x3A4658,
                "bottom": 0x12161E,
                "accent": 0xD8DEE8,
            },
            "snowStudy",
            16,
        ),
    )
    specs: list[dict[str, Any]] = []
    for scene_id, palette, visual_style, sort_order in appearances:
        if (preset := review_preset(scene_id)) is None:
            continue
        specs.append(
            {
                "id": scene_id,
                "name": preset["name"],
                "subtitle": preset["subtitle"],
                "description": preset["subtitle"],
                "category": "whisper",
                "tags": preset["tags"],
                "palette": palette,
                "visual_style": visual_style,
                "recommended_duration_seconds": preset["timeline"][
                    "duration_hint_seconds"
                ],
                "is_demo_playable": True,
                "sort_order": sort_order,
                "mock_listener_count": 0,
                "tracks": _preset_tracks(preset),
            }
        )
    return specs
