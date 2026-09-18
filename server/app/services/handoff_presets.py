"""Opt-in review catalog; the fixture ships inside the standalone backend image."""

import json
import uuid
from functools import lru_cache
from pathlib import Path
from typing import Any, cast

from app.core.config import get_settings

FIREPLACE_SCENE_ID = uuid.UUID("a1111111-1111-4111-8111-11111111110d")
FIXTURE = Path(__file__).resolve().parent.parent / "fixtures/handoff_fireplace_v4.json"


@lru_cache
def _fireplace_fixture() -> dict[str, Any]:
    preset = cast(dict[str, Any], json.loads(FIXTURE.read_text(encoding="utf-8")))
    try:
        release_ready = preset["releaseReady"]
        usage = preset["usage"]
        scene_id = uuid.UUID(preset["sceneID"])
        source_ids = [uuid.UUID(source["id"]) for source in preset["sources"]]
        resource_keys = [source["resourceName"] for source in preset["sources"]]
        timeline_scene_id = uuid.UUID(preset["timeline"]["scene_id"])
    except (KeyError, TypeError, ValueError) as error:
        raise ValueError("Invalid fireplace review fixture") from error
    if (
        release_ready is not False
        or usage != "debug_review_only"
        or scene_id != FIREPLACE_SCENE_ID
        or timeline_scene_id != FIREPLACE_SCENE_ID
        or not source_ids
        or len(source_ids) != len(set(source_ids))
        or any(not isinstance(key, str) or not key for key in resource_keys)
    ):
        raise ValueError("Invalid fireplace review fixture")
    return preset


def fireplace_review() -> dict[str, Any] | None:
    return _fireplace_fixture() if get_settings().handoff_review_presets_enabled else None


def apply_fireplace_review(spec: dict[str, Any]) -> dict[str, Any]:
    if spec["id"] != FIREPLACE_SCENE_ID or (preset := fireplace_review()) is None:
        return spec
    return {
        **spec,
        "name": preset["name"],
        "subtitle": preset["subtitle"],
        "description": preset["subtitle"],
        "tags": preset["tags"],
        "is_demo_playable": True,
        "recommended_duration_seconds": preset["timeline"]["duration_hint_seconds"],
        "tracks": [
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
        ],
    }
