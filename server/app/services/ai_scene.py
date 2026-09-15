"""DeepSeek backed scene-assist generation and composition normalization."""

from __future__ import annotations

import copy
import json
import logging
import time
import uuid
from collections.abc import Callable
from typing import Any

from pydantic import ValidationError

from app.schemas.ai_scene import (
    AdjustRequest,
    ArrangementPlan,
    ArrangementRequest,
    CompileRequest,
    GenerateRequest,
    SceneAdjustResult,
    SceneAssistResult,
    SceneOutline,
)
from app.services.ai_scene_prompts import (
    build_adjust_prompts,
    build_arrangement_prompts,
    build_compile_prompts,
    build_outline_prompts,
)
from app.services.composition import CompositionValidationError, validate_composition
from app.services.deepseek import DeepSeekConfigurationError, DeepSeekProviderError

logger = logging.getLogger(__name__)


class SceneAssistGenerationError(RuntimeError):
    """Raised when the model cannot produce a valid scene package."""


class SceneAssistSourceReferenceError(SceneAssistGenerationError):
    """Raised when generated output references an unselected source."""


_NAMESPACE = uuid.UUID("c0f4e4a2-b0ea-4e44-9b8a-0c5d5f6e2f1a")


def _content(response: Any) -> str | dict[str, Any]:
    value = getattr(response, "content", response)
    if isinstance(value, dict):
        return value
    if not isinstance(value, str):
        raise SceneAssistGenerationError("DeepSeek returned non-text JSON content")
    try:
        parsed = json.loads(value)
    except json.JSONDecodeError as exc:
        raise SceneAssistGenerationError("DeepSeek returned invalid JSON") from exc
    if not isinstance(parsed, dict):
        raise SceneAssistGenerationError("DeepSeek JSON response must be an object")
    return parsed


async def _complete(
    client: Any, system: str, user: str, *, stage: str = "unknown"
) -> dict[str, Any]:
    started = time.perf_counter()
    try:
        response = await client.complete(system_prompt=system, user_prompt=user, max_tokens=8_192)
    except SceneAssistGenerationError:
        raise
    except (DeepSeekConfigurationError, DeepSeekProviderError):
        raise
    except Exception as exc:
        raise SceneAssistGenerationError("DeepSeek generation failed") from exc
    elapsed_ms = round((time.perf_counter() - started) * 1000, 1)
    usage = getattr(response, "usage", {})
    model = getattr(response, "model", "unknown")
    logger.info(
        "ai_scene stage=%s model=%s elapsed_ms=%s usage=%s", stage, model, elapsed_ms, usage
    )
    return _content(response)


async def _with_repair(
    client: Any,
    prompts: tuple[str, str],
    parser: Callable[[dict[str, Any]], Any],
    *,
    stage: str,
) -> Any:
    # One repair is reserved for parsed JSON/schema/composition validation failures.
    # Provider HTTP or malformed-response errors are typed provider failures and bypass repair.
    system, user = prompts
    original: dict[str, Any] | None = None
    error: Exception | None = None
    for attempt in range(2):
        try:
            payload = await _complete(client, system, user, stage=stage)
            if original is None:
                original = payload
            return parser(payload)
        except (
            SceneAssistGenerationError,
            ValidationError,
            CompositionValidationError,
            ValueError,
        ) as exc:
            error = exc
            if attempt == 0:
                user = (
                    f"{user}\nRepair the JSON below. Return the complete corrected object, "
                    f"not a patch. Validation error: {exc}\nOriginal JSON:\n"
                    f"{json.dumps(original or {}, ensure_ascii=False, separators=(',', ':'))}"
                )
    raise SceneAssistGenerationError(f"Scene generation failed after repair: {error}") from error


def _source_maps(request: Any) -> tuple[dict[str, Any], dict[str, Any]]:
    by_id = {str(source.source_id): source for source in request.selected_sources}
    by_key = {source.resource_key: source for source in request.selected_sources}
    return by_id, by_key


def _source(value: Any, by_id: dict[str, Any], by_key: dict[str, Any]) -> Any:
    source_id = value.get("source_id", value.get("asset_id")) if isinstance(value, dict) else None
    resource_key = value.get("resource_key") if isinstance(value, dict) else None
    selected_by_id = by_id.get(str(source_id)) if source_id is not None else None
    selected_by_key = by_key.get(str(resource_key)) if resource_key is not None else None
    if source_id is not None and selected_by_id is None:
        raise SceneAssistSourceReferenceError(
            f"Generated source_id is not in selected catalog: {source_id}"
        )
    if resource_key is not None and selected_by_key is None:
        raise SceneAssistSourceReferenceError(
            f"Generated resource_key is not in selected catalog: {resource_key}"
        )
    if (
        selected_by_id is not None
        and selected_by_key is not None
        and selected_by_id.source_id != selected_by_key.source_id
    ):
        raise SceneAssistSourceReferenceError(
            "Generated source_id and resource_key refer to different sources"
        )
    selected = selected_by_id or selected_by_key
    if selected is None:
        raise SceneAssistSourceReferenceError(
            f"Generated source reference is not in selected catalog: {source_id or resource_key}"
        )
    return selected


def _parse_outline(payload: dict[str, Any]) -> SceneOutline:
    return SceneOutline.model_validate(payload.get("outline", payload))


def _parse_arrangement(payload: dict[str, Any], request: ArrangementRequest) -> ArrangementPlan:
    plan = ArrangementPlan.model_validate(payload.get("arrangement", payload))
    by_id, by_key = _source_maps(request)
    tracks = []
    for track in plan.tracks:
        source = _source(track.model_dump(), by_id, by_key)
        values = track.model_dump()
        values["source_id"] = source.source_id
        values["resource_key"] = source.resource_key
        tracks.append(type(track).model_validate(values))
    return ArrangementPlan(tracks=tracks)


def _stable(label: str) -> str:
    return str(uuid.uuid5(_NAMESPACE, label))


def _composition_from_arrangement(
    raw: dict[str, Any],
    request: CompileRequest | AdjustRequest,
    arrangement: ArrangementPlan,
) -> dict[str, Any]:
    by_id, by_key = _source_maps(request)
    duration = request.options.duration_seconds or 0.0
    if not duration:
        duration = max(track.end_seconds for track in arrangement.tracks)
    composition = copy.deepcopy(raw) if isinstance(raw, dict) else {}
    composition["schema"] = "scene_composition_v2"
    composition["version"] = int(composition.get("version", 2))
    groups = composition.get("source_groups")
    clips = composition.get("clips")
    if not isinstance(groups, list) or not groups:
        groups = []
        clips = []
        group_ids: dict[str, str] = {}
        for index, track in enumerate(arrangement.tracks):
            source = _source(track.model_dump(), by_id, by_key)
            key = str(source.source_id)
            group_id = group_ids.setdefault(key, _stable(f"group:{key}"))
            if not any(item.get("id") == group_id for item in groups):
                groups.append(
                    {
                        "id": group_id,
                        "name": source.name,
                        "symbol_name": None,
                        "layer": source.layer,
                        "display_policy": "while_active",
                        "position_keyframes": [item.model_dump() for item in track.keyframes],
                    }
                )
            clips.append(
                {
                    "id": _stable(f"clip:{index}:{key}:{track.start_seconds}"),
                    "source_group_id": group_id,
                    "asset_id": str(source.source_id),
                    "resource_key": source.resource_key,
                    "start_seconds": track.start_seconds,
                    "end_seconds": track.end_seconds,
                    "source_offset_seconds": 0,
                    "playback_mode": "loop" if track.loop else "oneshot",
                    "crossfade_ms": max(track.fade_in_ms, track.fade_out_ms),
                    "fade_in_ms": track.fade_in_ms,
                    "fade_out_ms": track.fade_out_ms,
                }
            )
    else:
        group_sources: dict[str, Any] = {}
        clip_sources = {
            str(clip.get("source_group_id")): _source(clip, by_id, by_key)
            for clip in (clips or [])
            if isinstance(clip, dict)
            and clip.get("source_group_id") is not None
            and any(clip.get(key) is not None for key in ("source_id", "asset_id", "resource_key"))
        }
        for index, group in enumerate(groups):
            if not isinstance(group, dict):
                raise CompositionValidationError("source group must be an object")
            group.setdefault("id", _stable(f"group:{index}"))
            source = (
                _source(group, by_id, by_key)
                if any(
                    group.get(key) is not None for key in ("source_id", "asset_id", "resource_key")
                )
                else clip_sources.get(str(group.get("id")))
            )
            if source is None:
                raise SceneAssistSourceReferenceError(
                    "Generated source group has no source_id/resource_key"
                )
            group["id"] = (
                str(uuid.UUID(str(group["id"])))
                if _is_uuid(group["id"])
                else _stable(f"group:{source.source_id}:{index}")
            )
            group.setdefault("name", source.name)
            group.setdefault("layer", source.layer)
            group.setdefault("display_policy", "while_active")
            group.setdefault(
                "position_keyframes",
                [{"t": 0, "angle": source.angle, "radius": source.radius}],
            )
            group_sources[str(group["id"])] = source
        _normalize_clip_sources(clips or [], group_sources, by_id, by_key)
    composition["duration_seconds"] = float(composition.get("duration_seconds", duration))
    composition["source_groups"] = groups
    composition["clips"] = clips or []
    return validate_composition(composition)


def _is_uuid(value: Any) -> bool:
    try:
        uuid.UUID(str(value))
        return True
    except (TypeError, ValueError):
        return False


async def generate_outline(client: Any, request: Any) -> SceneOutline:
    return await _with_repair(
        client, build_outline_prompts(request), _parse_outline, stage="outline"
    )


async def generate_arrangement(client: Any, request: ArrangementRequest) -> ArrangementPlan:
    return await _with_repair(
        client,
        build_arrangement_prompts(request),
        lambda payload: _parse_arrangement(payload, request),
        stage="arrangement",
    )


async def compile_scene(client: Any, request: CompileRequest) -> SceneAssistResult:
    def parse(payload: dict[str, Any]) -> SceneAssistResult:
        scene = payload.get("scene")
        if not isinstance(scene, dict):
            raise SceneAssistGenerationError("scene must be an object")
        composition = _composition_from_arrangement(
            payload.get("composition", {}), request, request.arrangement
        )
        return SceneAssistResult(
            outline=request.outline,
            arrangement=request.arrangement,
            scene=scene,
            composition=composition,
            validation_warnings=payload.get("validation_warnings", []),
        )

    return await _with_repair(client, build_compile_prompts(request), parse, stage="compile")


async def generate_scene(client: Any, request: GenerateRequest) -> SceneAssistResult:
    outline = await generate_outline(client, request)
    arrangement_request = ArrangementRequest.model_validate(
        {**request.model_dump(), "outline": outline.model_dump()}
    )
    arrangement = await generate_arrangement(client, arrangement_request)
    compile_request = CompileRequest.model_validate(
        {
            **request.model_dump(),
            "outline": outline.model_dump(),
            "arrangement": arrangement.model_dump(),
        }
    )
    return await compile_scene(client, compile_request)


async def adjust_scene(client: Any, request: AdjustRequest) -> SceneAdjustResult:
    def parse(payload: dict[str, Any]) -> SceneAdjustResult:
        scene = payload.get("scene")
        if not isinstance(scene, dict):
            raise SceneAssistGenerationError("scene must be an object")
        arrangement_data = request.scene.get("arrangement")
        arrangement = (
            ArrangementPlan.model_validate(arrangement_data)
            if isinstance(arrangement_data, dict)
            else None
        )
        if arrangement is None:
            composition = _normalize_existing_composition(payload.get("composition", {}), request)
        else:
            composition = _composition_from_arrangement(
                payload.get("composition", {}), request, arrangement
            )
        return SceneAdjustResult(
            scene=scene,
            composition=composition,
            change_summary=payload.get("change_summary", []),
            validation_warnings=payload.get("validation_warnings", []),
        )

    return await _with_repair(client, build_adjust_prompts(request), parse, stage="adjust")


def _normalize_existing_composition(raw: dict[str, Any], request: AdjustRequest) -> dict[str, Any]:
    """Normalize a model supplied complete v2 document while enforcing source refs."""
    composition = copy.deepcopy(raw)
    by_id, by_key = _source_maps(request)
    groups = composition.get("source_groups")
    clips = composition.get("clips")
    if not isinstance(groups, list) or not groups or not isinstance(clips, list) or not clips:
        raise CompositionValidationError("adjustment must return source_groups and clips")
    group_ids: list[str] = []
    for index, group in enumerate(groups):
        if not isinstance(group, dict):
            raise CompositionValidationError("source group must be an object")
        source = (
            _source(group, by_id, by_key)
            if any(group.get(key) is not None for key in ("source_id", "asset_id", "resource_key"))
            else next(
                (
                    _source(clip, by_id, by_key)
                    for clip in clips
                    if isinstance(clip, dict)
                    and str(clip.get("source_group_id")) == str(group.get("id"))
                    and any(
                        clip.get(key) is not None
                        for key in ("source_id", "asset_id", "resource_key")
                    )
                ),
                None,
            )
        )
        if source is None:
            raise SceneAssistSourceReferenceError("Generated source group has no resolvable source")
        group.setdefault("id", _stable(f"adjust-group:{index}:{source.source_id}"))
        group.setdefault("name", source.name)
        group.setdefault("layer", source.layer)
        group.setdefault("display_policy", "while_active")
        group.setdefault(
            "position_keyframes",
            [{"t": 0, "angle": source.angle, "radius": source.radius}],
        )
        group_ids.append(str(group["id"]))
    group_sources = {
        str(group["id"]): (
            _source(group, by_id, by_key)
            if any(group.get(key) is not None for key in ("source_id", "asset_id", "resource_key"))
            else next(
                (
                    _source(clip, by_id, by_key)
                    for clip in clips
                    if isinstance(clip, dict)
                    and str(clip.get("source_group_id")) == str(group["id"])
                    and any(
                        clip.get(key) is not None
                        for key in ("source_id", "asset_id", "resource_key")
                    )
                ),
                None,
            )
        )
        for group in groups
    }
    if any(source is None for source in group_sources.values()):
        raise SceneAssistSourceReferenceError("Generated source group has no resolvable source")
    for index, clip in enumerate(clips):
        if isinstance(clip, dict):
            clip.setdefault("id", _stable(f"adjust-clip:{index}"))
    _normalize_clip_sources(clips, group_sources, by_id, by_key)
    normalized = validate_composition(composition)
    existing = request.scene.get("composition", request.scene)
    if isinstance(existing, dict):
        required = _composition_source_set(existing, by_id, by_key)
        returned = _composition_source_set(normalized, by_id, by_key)
        if not required.issubset(returned):
            missing = sorted(required - returned)
            raise SceneAssistSourceReferenceError(
                f"Adjustment omitted existing source references: {missing}"
            )
        existing_bindings = _composition_bindings(existing, by_id, by_key)
        returned_bindings = _composition_bindings(normalized, by_id, by_key)
        for binding_key, source_id in existing_bindings.items():
            if returned_bindings.get(binding_key) != source_id:
                raise SceneAssistSourceReferenceError(
                    f"Adjustment changed existing source binding: {binding_key}"
                )
    return normalized


def _normalize_clip_sources(
    clips: list[Any], group_sources: dict[str, Any], by_id: dict[str, Any], by_key: dict[str, Any]
) -> None:
    for clip in clips:
        if not isinstance(clip, dict):
            raise CompositionValidationError("clip must be an object")
        group_id = str(clip.get("source_group_id"))
        group_source = group_sources.get(group_id)
        if group_source is None:
            raise CompositionValidationError(
                "clip source_group_id does not reference a source group"
            )
        clip_source = (
            _source(clip, by_id, by_key)
            if (
                clip.get("source_id") is not None
                or clip.get("asset_id") is not None
                or clip.get("resource_key") is not None
                or clip.get("name") is not None
            )
            else group_source
        )
        if clip_source.source_id != group_source.source_id:
            raise SceneAssistSourceReferenceError("clip source does not match its source group")
        clip.setdefault("asset_id", str(group_source.source_id))
        clip.setdefault("resource_key", group_source.resource_key)


def _composition_source_set(
    composition: dict[str, Any], by_id: dict[str, Any], by_key: dict[str, Any]
) -> set[str]:
    refs: set[str] = set()
    groups = composition.get("source_groups", [])
    clips = composition.get("clips", [])
    if isinstance(groups, list):
        for item in groups:
            if isinstance(item, dict) and any(
                item.get(key) is not None for key in ("source_id", "asset_id", "resource_key")
            ):
                refs.add(str(_source(item, by_id, by_key).source_id))
    if isinstance(clips, list):
        for item in clips:
            if isinstance(item, dict) and any(
                item.get(key) is not None for key in ("source_id", "asset_id", "resource_key")
            ):
                refs.add(str(_source(item, by_id, by_key).source_id))
    return refs


def _composition_bindings(
    composition: dict[str, Any], by_id: dict[str, Any], by_key: dict[str, Any]
) -> dict[str, str]:
    """Return stable group/clip IDs mapped to selected source IDs."""
    bindings: dict[str, str] = {}
    groups = composition.get("source_groups", [])
    group_sources: dict[str, Any] = {}
    clips = composition.get("clips", [])
    clip_sources = (
        {
            str(clip.get("source_group_id")): _source(clip, by_id, by_key)
            for clip in clips
            if isinstance(clip, dict)
            and clip.get("source_group_id") is not None
            and any(clip.get(key) is not None for key in ("source_id", "asset_id", "resource_key"))
        }
        if isinstance(clips, list)
        else {}
    )
    if isinstance(groups, list):
        for group in groups:
            if isinstance(group, dict) and group.get("id") is not None:
                source = (
                    _source(group, by_id, by_key)
                    if any(
                        group.get(key) is not None
                        for key in ("source_id", "asset_id", "resource_key")
                    )
                    else clip_sources.get(str(group["id"]))
                )
                if source is None:
                    raise SceneAssistSourceReferenceError(
                        f"Source group has no resolvable source: {group['id']}"
                    )
                group_id = str(group["id"])
                group_sources[group_id] = source
                bindings[f"group:{group_id}"] = str(source.source_id)
    clips = composition.get("clips", [])
    if isinstance(clips, list):
        for clip in clips:
            if not isinstance(clip, dict) or clip.get("id") is None:
                continue
            group_source = group_sources.get(str(clip.get("source_group_id")))
            source = (
                _source(clip, by_id, by_key)
                if clip.get("source_id") is not None
                or clip.get("asset_id") is not None
                or clip.get("resource_key") is not None
                or clip.get("name") is not None
                else group_source
            )
            if source is None:
                raise SceneAssistSourceReferenceError(
                    f"Clip has no resolvable source: {clip['id']}"
                )
            bindings[f"clip:{clip['id']}"] = str(source.source_id)
    return bindings
