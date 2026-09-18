"""Resolve content presets from trusted snapshots; never manufacture approvals."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from app.schemas.ai_generation import GenerationRequestError
from app.services.ai_generation_bindings import (
    AssetCatalog,
    FrameBindingIndex,
    SelectedBindings,
    resolve_selected_bindings,
)


@dataclass(frozen=True)
class ContentPreset:
    content_preset_id: str
    version: str
    status: str
    framework_ids: frozenset[str]
    primary_goals: frozenset[str]
    allowed_state_tags: frozenset[str]


@dataclass(frozen=True)
class ContentPresetRegistry:
    version: str
    presets: tuple[ContentPreset, ...]


@dataclass(frozen=True)
class PresetResolution:
    selection: SelectedBindings
    candidates: tuple[ContentPreset, ...]
    selected_preset: ContentPreset | None
    registry_version: str


class ContentPresetError(GenerationRequestError):
    def __init__(self, reason_code: str) -> None:
        self.reason_code = reason_code
        super().__init__("INCOMPATIBLE_CONTENT_PRESET", ("content_preset_id",), reason_code)


def resolve_content_presets(
    payload: dict[str, Any], *, catalog: AssetCatalog, binding_index: FrameBindingIndex,
    registry: ContentPresetRegistry,
) -> PresetResolution:
    """Keep an explicit selection or resolve a unique candidate, without ranking.

    Multiple compatible candidates leave selected_preset unset for clarification.
    Registry records and binding permissions must come from trusted server adapters.
    """
    selection = resolve_selected_bindings(payload, catalog=catalog, binding_index=binding_index)
    request = selection.request
    if not registry.version.strip():
        raise ContentPresetError("MISSING_PRESET_REGISTRY_VERSION")
    ids = [preset.content_preset_id for preset in registry.presets]
    if len(ids) != len(set(ids)):
        raise ContentPresetError("AMBIGUOUS_PRESET_ID")
    requested_id = request.get("content_preset_id")
    if requested_id is not None and requested_id not in ids:
        raise ContentPresetError("UNKNOWN_CONTENT_PRESET")
    candidates = []
    for preset in registry.presets:
        if requested_id is not None and preset.content_preset_id != requested_id:
            continue
        reason = _incompatibility(preset, selection)
        if reason is not None:
            if requested_id is not None:
                raise ContentPresetError(reason)
            continue
        candidates.append(preset)
    if not candidates:
        raise ContentPresetError("NO_COMPATIBLE_PRESET")
    candidates.sort(key=lambda preset: preset.content_preset_id)
    return PresetResolution(selection, tuple(candidates),
                            candidates[0] if len(candidates) == 1 else None, registry.version)


def _incompatibility(preset: ContentPreset, selection: SelectedBindings) -> str | None:
    if preset.status != "approved":
        return "PRESET_NOT_APPROVED"
    if not preset.content_preset_id.strip() or not preset.version.strip():
        return "INCOMPLETE_PRESET"
    request = selection.request
    if request["user_context"]["primary_goal"] not in preset.primary_goals:
        return "PRESET_GOAL_MISMATCH"
    if not set(request["user_context"]["state_tags"]).issubset(preset.allowed_state_tags):
        return "PRESET_STATE_MISMATCH"
    if request["framework"]["framework_id"] not in preset.framework_ids:
        return "PRESET_FRAMEWORK_MISMATCH"
    if any(preset.content_preset_id not in binding.allowed_content_presets
           for binding in selection.bindings):
        return "PRESET_BINDING_MISMATCH"
    return None
