"""Validate and normalize scene_composition_v1 documents."""

from __future__ import annotations

import copy
import math
import uuid
from typing import Any

SCHEMA_ID = "scene_composition_v1"


class CompositionValidationError(ValueError):
    def __init__(
        self,
        message: str,
        *,
        track_id: str | None = None,
        keyframe_index: int | None = None,
    ) -> None:
        super().__init__(message)
        self.message = message
        self.track_id = track_id
        self.keyframe_index = keyframe_index

    def as_detail(self) -> dict[str, Any]:
        detail: dict[str, Any] = {"message": self.message}
        if self.track_id is not None:
            detail["track_id"] = self.track_id
        if self.keyframe_index is not None:
            detail["keyframe_index"] = self.keyframe_index
        return detail


def _fail(
    message: str,
    *,
    track_id: str | None = None,
    keyframe_index: int | None = None,
) -> None:
    raise CompositionValidationError(
        message, track_id=track_id, keyframe_index=keyframe_index
    )


def _as_float(
    value: Any,
    field: str,
    *,
    track_id: str | None = None,
    keyframe_index: int | None = None,
) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        _fail(f"{field} must be a number", track_id=track_id, keyframe_index=keyframe_index)
    number = float(value)
    if not math.isfinite(number):
        _fail(f"{field} must be finite", track_id=track_id, keyframe_index=keyframe_index)
    return number


def _validate_keyframe(
    raw: Any,
    index: int,
    *,
    track_id: str,
    start: float,
    end: float,
    prev_t: float | None,
) -> dict[str, float]:
    if not isinstance(raw, dict):
        _fail("Keyframe must be an object", track_id=track_id, keyframe_index=index)

    t = _as_float(raw.get("t"), "t", track_id=track_id, keyframe_index=index)
    if t < start or t > end:
        _fail("Keyframe t out of track range", track_id=track_id, keyframe_index=index)
    if prev_t is not None and t <= prev_t:
        _fail("Keyframe t must be strictly increasing", track_id=track_id, keyframe_index=index)

    angle = _as_float(raw.get("angle"), "angle", track_id=track_id, keyframe_index=index)
    radius = _as_float(raw.get("radius"), "radius", track_id=track_id, keyframe_index=index)
    if radius < 0 or radius > 1:
        _fail("radius must be in [0, 1]", track_id=track_id, keyframe_index=index)
    return {"t": t, "angle": angle, "radius": radius}


def _validate_track(raw: Any, index: int) -> dict[str, Any]:
    if not isinstance(raw, dict):
        _fail(f"tracks[{index}] must be an object")

    track_id_raw = raw.get("id")
    track_id = str(track_id_raw) if track_id_raw is not None else f"tracks[{index}]"
    try:
        track_uuid = uuid.UUID(str(track_id_raw))
    except (TypeError, ValueError):
        _fail("track id must be a UUID", track_id=track_id)

    asset_id = raw.get("asset_id")
    resource_key = raw.get("resource_key")
    asset_id_str: str | None = None
    if asset_id is not None:
        try:
            asset_id_str = str(uuid.UUID(str(asset_id)))
        except (TypeError, ValueError):
            _fail("asset_id must be a UUID when set", track_id=str(track_uuid))
    resource_key_str: str | None = None
    if resource_key is not None:
        if not isinstance(resource_key, str) or not resource_key.strip():
            _fail("resource_key must be a non-empty string when set", track_id=str(track_uuid))
        resource_key_str = resource_key.strip()
    if asset_id_str is None and resource_key_str is None:
        _fail("asset_id or resource_key is required", track_id=str(track_uuid))

    start = _as_float(raw.get("start_seconds"), "start_seconds", track_id=str(track_uuid))
    end = _as_float(raw.get("end_seconds"), "end_seconds", track_id=str(track_uuid))
    if start < 0:
        _fail("start_seconds must be >= 0", track_id=str(track_uuid))
    if end <= start:
        _fail("end_seconds must be greater than start_seconds", track_id=str(track_uuid))

    layer = raw.get("layer", "ambience")
    if not isinstance(layer, str) or not layer.strip():
        _fail("layer must be a non-empty string", track_id=str(track_uuid))

    loop = raw.get("loop", True)
    if not isinstance(loop, bool):
        _fail("loop must be a boolean", track_id=str(track_uuid))

    source_duration = raw.get("source_duration_seconds")
    source_duration_out: float | None = None
    if source_duration is not None:
        source_duration_out = _as_float(
            source_duration, "source_duration_seconds", track_id=str(track_uuid)
        )
        if source_duration_out <= 0:
            _fail("source_duration_seconds must be > 0 when set", track_id=str(track_uuid))

    keyframes_raw = raw.get("keyframes")
    if not isinstance(keyframes_raw, list) or not keyframes_raw:
        _fail("track must have at least one keyframe", track_id=str(track_uuid))

    keyframes: list[dict[str, float]] = []
    prev_t: float | None = None
    for kf_index, kf in enumerate(keyframes_raw):
        parsed = _validate_keyframe(
            kf,
            kf_index,
            track_id=str(track_uuid),
            start=start,
            end=end,
            prev_t=prev_t,
        )
        keyframes.append(parsed)
        prev_t = parsed["t"]

    out: dict[str, Any] = {
        "id": str(track_uuid),
        "asset_id": asset_id_str,
        "resource_key": resource_key_str,
        "layer": layer.strip(),
        "loop": loop,
        "start_seconds": start,
        "end_seconds": end,
        "keyframes": keyframes,
    }
    if source_duration_out is not None:
        out["source_duration_seconds"] = source_duration_out
    return out


def validate_composition(document: Any) -> dict[str, Any]:
    """Return a normalized composition dict or raise CompositionValidationError."""
    if not isinstance(document, dict):
        _fail("composition must be an object")

    schema = document.get("schema")
    if schema != SCHEMA_ID:
        _fail(f"schema must be {SCHEMA_ID}")

    version = document.get("version")
    if not isinstance(version, int) or isinstance(version, bool) or version < 1:
        _fail("version must be a positive integer")

    tracks_raw = document.get("tracks")
    if not isinstance(tracks_raw, list):
        _fail("tracks must be an array")
    if not tracks_raw:
        _fail("tracks must be a non-empty array")

    tracks = [_validate_track(item, index) for index, item in enumerate(tracks_raw)]
    duration = max(track["end_seconds"] for track in tracks)

    # Preserve unknown top-level keys except ones we rewrite.
    out = copy.deepcopy(document)
    out["schema"] = SCHEMA_ID
    out["version"] = version
    out["duration_seconds"] = duration
    out["tracks"] = tracks
    return out
