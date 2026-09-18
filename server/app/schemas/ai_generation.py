"""Request gate for ai-scene-generation-v1; independent of legacy scene-assist."""

from __future__ import annotations

import copy
import json
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator

_SCHEMA_PATH = Path(__file__).with_name("ai-scene-generation-request.schema.json")
_SCHEMA = json.loads(_SCHEMA_PATH.read_text(encoding="utf-8"))
Draft202012Validator.check_schema(_SCHEMA)
_VALIDATOR = Draft202012Validator(_SCHEMA)


class GenerationRequestError(ValueError):
    """Safe error metadata: never include request values or free text in messages."""

    def __init__(self, code: str, path: tuple[str | int, ...], reason: str) -> None:
        self.code = code
        self.path = path
        super().__init__(f"{code}: {reason}")


def validate_generation_request(payload: dict[str, Any]) -> dict[str, Any]:
    """Validate decoded JSON and unique object IDs, returning an independent copy.

    This is a structural gate, not authorization, catalog approval or compilation.
    Optional fields stay absent; do not infer goals, states or source versions.
    """
    try:
        json.dumps(payload, allow_nan=False)
    except (TypeError, ValueError):
        raise GenerationRequestError("INVALID_REQUEST", (), "non-JSON value") from None
    error = next(_VALIDATOR.iter_errors(payload), None)
    if error is not None:
        path = tuple(error.absolute_path)
        code = {
            (("selected_sounds",), "maxItems"): "TOO_MANY_SOUND_OBJECTS",
            (("user_context", "primary_goal"), "enum"): "UNKNOWN_GOAL",
            (("framework", "framework_id"), "enum"): "UNKNOWN_FRAMEWORK",
        }.get((path, error.validator), "INVALID_REQUEST")
        raise GenerationRequestError(code, path, f"schema rule {error.validator} failed")
    sound_ids = [sound["sound_object_id"] for sound in payload["selected_sounds"]]
    if len(sound_ids) != len(set(sound_ids)):
        raise GenerationRequestError(
            "INVALID_REQUEST", ("selected_sounds",), "duplicate sound_object_id"
        )
    return copy.deepcopy(payload)
