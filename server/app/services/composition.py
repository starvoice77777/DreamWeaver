"""Validate and normalize scene composition v1/v2 documents."""

from __future__ import annotations

import copy
import math
import uuid
from typing import Any

SCHEMA_V1 = "scene_composition_v1"
SCHEMA_V2 = "scene_composition_v2"
SUPPORTED_SCHEMAS = {SCHEMA_V1, SCHEMA_V2}
INTERPOLATIONS = {"linear", "smoothstep", "recorded_linear"}
PLAYBACK_MODES = {"oneshot", "loop", "bounded_loop"}
LAYERS = {"environment", "trigger", "voice", "ambience"}


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
    require_range: bool = True,
) -> dict[str, Any]:
    if not isinstance(raw, dict):
        _fail("Keyframe must be an object", track_id=track_id, keyframe_index=index)

    t = _as_float(raw.get("t"), "t", track_id=track_id, keyframe_index=index)
    if require_range and (t < start or t > end):
        _fail("Keyframe t out of track range", track_id=track_id, keyframe_index=index)
    if prev_t is not None and t <= prev_t:
        _fail("Keyframe t must be strictly increasing", track_id=track_id, keyframe_index=index)

    angle = _as_float(raw.get("angle"), "angle", track_id=track_id, keyframe_index=index)
    radius = _as_float(raw.get("radius"), "radius", track_id=track_id, keyframe_index=index)
    if radius < 0 or radius > 1:
        _fail("radius must be in [0, 1]", track_id=track_id, keyframe_index=index)
    interpolation = raw.get("interpolation", "linear")
    if interpolation not in INTERPOLATIONS:
        _fail(
            f"interpolation must be one of {sorted(INTERPOLATIONS)}",
            track_id=track_id,
            keyframe_index=index,
        )
    return {
        "t": t,
        "angle": angle,
        "radius": radius,
        "interpolation": interpolation,
    }


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

    keyframes: list[dict[str, Any]] = []
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


def _validate_source_group(raw: Any, index: int, *, duration: float) -> dict[str, Any]:
    if not isinstance(raw, dict):
        _fail(f"source_groups[{index}] must be an object")
    raw_id = raw.get("id")
    label = str(raw_id) if raw_id is not None else f"source_groups[{index}]"
    try:
        group_id = str(uuid.UUID(str(raw_id)))
    except (TypeError, ValueError):
        _fail("source group id must be a UUID", track_id=label)

    name = raw.get("name")
    if not isinstance(name, str) or not name.strip():
        _fail("source group name must be a non-empty string", track_id=group_id)
    layer = raw.get("layer", "ambience")
    if layer not in LAYERS:
        _fail(f"source group layer must be one of {sorted(LAYERS)}", track_id=group_id)
    symbol_name = raw.get("symbol_name")
    if symbol_name is not None and (
        not isinstance(symbol_name, str) or not symbol_name.strip()
    ):
        _fail("symbol_name must be a non-empty string when set", track_id=group_id)
    display_policy = raw.get("display_policy", "selected_or_active")
    if display_policy not in {"always_in_window", "while_active", "selected_or_active"}:
        _fail("invalid source group display_policy", track_id=group_id)

    raw_keyframes = raw.get("position_keyframes")
    if not isinstance(raw_keyframes, list) or not raw_keyframes:
        _fail("source group must have at least one position keyframe", track_id=group_id)
    keyframes: list[dict[str, Any]] = []
    previous: float | None = None
    for keyframe_index, keyframe in enumerate(raw_keyframes):
        parsed = _validate_keyframe(
            keyframe,
            keyframe_index,
            track_id=group_id,
            start=0,
            end=duration,
            prev_t=previous,
        )
        keyframes.append(parsed)
        previous = parsed["t"]

    return {
        "id": group_id,
        "name": name.strip(),
        "symbol_name": symbol_name.strip() if symbol_name is not None else None,
        "layer": layer,
        "display_policy": display_policy,
        "position_keyframes": keyframes,
    }


def _validate_clip(
    raw: Any,
    index: int,
    *,
    duration: float,
    source_group_ids: set[str],
) -> dict[str, Any]:
    if not isinstance(raw, dict):
        _fail(f"clips[{index}] must be an object")
    raw_id = raw.get("id")
    label = str(raw_id) if raw_id is not None else f"clips[{index}]"
    try:
        clip_id = str(uuid.UUID(str(raw_id)))
    except (TypeError, ValueError):
        _fail("clip id must be a UUID", track_id=label)
    try:
        source_group_id = str(uuid.UUID(str(raw.get("source_group_id"))))
    except (TypeError, ValueError):
        _fail("source_group_id must be a UUID", track_id=clip_id)
    if source_group_id not in source_group_ids:
        _fail("source_group_id does not reference a source group", track_id=clip_id)

    asset_id = raw.get("asset_id")
    resource_key = raw.get("resource_key")
    asset_id_out: str | None = None
    if asset_id is not None:
        try:
            asset_id_out = str(uuid.UUID(str(asset_id)))
        except (TypeError, ValueError):
            _fail("asset_id must be a UUID when set", track_id=clip_id)
    resource_key_out: str | None = None
    if resource_key is not None:
        if not isinstance(resource_key, str) or not resource_key.strip():
            _fail("resource_key must be a non-empty string when set", track_id=clip_id)
        resource_key_out = resource_key.strip()
    if asset_id_out is None and resource_key_out is None:
        _fail("asset_id or resource_key is required", track_id=clip_id)

    start = _as_float(raw.get("start_seconds"), "start_seconds", track_id=clip_id)
    end = _as_float(raw.get("end_seconds"), "end_seconds", track_id=clip_id)
    if start < 0 or end <= start or end > duration:
        _fail("clip time window must be inside composition duration", track_id=clip_id)
    offset = _as_float(
        raw.get("source_offset_seconds", 0),
        "source_offset_seconds",
        track_id=clip_id,
    )
    if offset < 0:
        _fail("source_offset_seconds must be >= 0", track_id=clip_id)

    playback_mode = raw.get("playback_mode", "oneshot")
    if playback_mode not in PLAYBACK_MODES:
        _fail(f"playback_mode must be one of {sorted(PLAYBACK_MODES)}", track_id=clip_id)
    crossfade = raw.get("crossfade_ms", 0)
    if not isinstance(crossfade, int) or isinstance(crossfade, bool) or crossfade < 0:
        _fail("crossfade_ms must be a non-negative integer", track_id=clip_id)
    if playback_mode == "oneshot" and crossfade != 0:
        _fail("oneshot clip crossfade_ms must be 0", track_id=clip_id)
    clip_duration_ms = (end - start) * 1000
    if crossfade * 2 >= clip_duration_ms and crossfade > 0:
        _fail("crossfade_ms must be less than half the clip duration", track_id=clip_id)
    fades: dict[str, int] = {}
    for field in ("fade_in_ms", "fade_out_ms"):
        value = raw.get(field, 0)
        if not isinstance(value, int) or isinstance(value, bool) or value < 0:
            _fail(f"{field} must be a non-negative integer", track_id=clip_id)
        if value > clip_duration_ms:
            _fail(f"{field} must not exceed clip duration", track_id=clip_id)
        fades[field] = value
    if fades["fade_in_ms"] + fades["fade_out_ms"] > clip_duration_ms:
        _fail("fade_in_ms + fade_out_ms must not exceed clip duration", track_id=clip_id)

    out = copy.deepcopy(raw)
    out.update(
        {
            "id": clip_id,
            "source_group_id": source_group_id,
            "asset_id": asset_id_out,
            "resource_key": resource_key_out,
            "start_seconds": start,
            "end_seconds": end,
            "source_offset_seconds": offset,
            "playback_mode": playback_mode,
            "crossfade_ms": crossfade,
            **fades,
        }
    )
    return out


def _validate_v2(document: dict[str, Any], *, version: int) -> dict[str, Any]:
    duration = _as_float(document.get("duration_seconds"), "duration_seconds")
    if duration <= 0:
        _fail("duration_seconds must be > 0")
    raw_groups = document.get("source_groups")
    raw_clips = document.get("clips")
    if not isinstance(raw_groups, list) or not raw_groups:
        _fail("source_groups must be a non-empty array")
    if not isinstance(raw_clips, list) or not raw_clips:
        _fail("clips must be a non-empty array")

    groups = [
        _validate_source_group(group, index, duration=duration)
        for index, group in enumerate(raw_groups)
    ]
    group_ids = [group["id"] for group in groups]
    if len(group_ids) != len(set(group_ids)):
        _fail("source group ids must be unique")
    clips = [
        _validate_clip(clip, index, duration=duration, source_group_ids=set(group_ids))
        for index, clip in enumerate(raw_clips)
    ]
    clip_ids = [clip["id"] for clip in clips]
    if len(clip_ids) != len(set(clip_ids)):
        _fail("clip ids must be unique")

    out = copy.deepcopy(document)
    out["schema"] = SCHEMA_V2
    out["version"] = version
    out["duration_seconds"] = duration
    out["source_groups"] = groups
    out["clips"] = clips
    out.pop("tracks", None)
    return out


def validate_composition(document: Any) -> dict[str, Any]:
    """Return a normalized composition dict or raise CompositionValidationError."""
    if not isinstance(document, dict):
        _fail("composition must be an object")

    schema = document.get("schema")
    if schema not in SUPPORTED_SCHEMAS:
        _fail(f"schema must be one of {sorted(SUPPORTED_SCHEMAS)}")

    version = document.get("version")
    if not isinstance(version, int) or isinstance(version, bool) or version < 1:
        _fail("version must be a positive integer")

    if schema == SCHEMA_V2:
        return _validate_v2(document, version=version)

    tracks_raw = document.get("tracks")
    if not isinstance(tracks_raw, list):
        _fail("tracks must be an array")
    if not tracks_raw:
        _fail("tracks must be a non-empty array")

    tracks = [_validate_track(item, index) for index, item in enumerate(tracks_raw)]
    duration = max(track["end_seconds"] for track in tracks)

    # Preserve unknown top-level keys except ones we rewrite.
    out = copy.deepcopy(document)
    out["schema"] = SCHEMA_V1
    out["version"] = version
    out["duration_seconds"] = duration
    out["tracks"] = tracks
    return out
