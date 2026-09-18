"""Resolve selected sounds against trusted, versioned server registry snapshots.

These projections are internal inputs, not client claims or production seed data.
Passing this gate does not establish preset, motion, role or timeline validity.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from app.schemas.ai_generation import GenerationRequestError, validate_generation_request


@dataclass(frozen=True)
class CatalogAsset:
    resource_key: str
    asset_status: str
    license_status: str
    qc_status: str


@dataclass(frozen=True)
class FrameBinding:
    binding_id: str
    binding_version: str
    resource_key: str
    framework_id: str
    visual_zone: str
    binding_status: str


@dataclass(frozen=True)
class AssetCatalog:
    version: str
    assets: tuple[CatalogAsset, ...]


@dataclass(frozen=True)
class FrameBindingIndex:
    version: str
    bindings: tuple[FrameBinding, ...]


@dataclass(frozen=True)
class SelectedBindings:
    request: dict[str, Any]
    bindings: tuple[FrameBinding, ...]  # Same order as request.selected_sounds.
    catalog_version: str
    binding_index_version: str


class BindingGateError(GenerationRequestError):
    def __init__(self, reason_code: str, path: tuple[str | int, ...] = ()) -> None:
        self.reason_code = reason_code
        super().__init__("NO_APPROVED_BINDING", path, reason_code)


def resolve_selected_bindings(
    payload: dict[str, Any], *, catalog: AssetCatalog, binding_index: FrameBindingIndex
) -> SelectedBindings:
    """Fail closed without replacing/dropping sounds, even when they are unlocked.

    Adapters must supply authorization/QC evidence from the server, never the request.
    Excluded selections require caller clarification; they are not silently removed.
    """
    request = validate_generation_request(payload)
    if not catalog.version.strip() or not binding_index.version.strip():
        raise BindingGateError("MISSING_DEPENDENCY_VERSION")
    framework_id = request["framework"]["framework_id"]
    excluded = set(request.get("excluded_resource_keys", []))
    resolved = []
    for position, sound in enumerate(request["selected_sounds"]):
        path = ("selected_sounds", position)
        key = sound["resource_key"]
        if key in excluded:
            raise BindingGateError("SELECTED_RESOURCE_EXCLUDED", path)
        assets = [asset for asset in catalog.assets if asset.resource_key == key]
        if len(assets) != 1:
            raise BindingGateError("MISSING_OR_AMBIGUOUS_ASSET", path)
        asset = assets[0]
        if (asset.asset_status, asset.license_status, asset.qc_status) != (
            "master", "approved", "approved"
        ):
            raise BindingGateError("ASSET_NOT_APPROVED", path)
        matches = [binding for binding in binding_index.bindings
                   if binding.resource_key == key and binding.framework_id == framework_id]
        if len(matches) != 1:
            raise BindingGateError("MISSING_OR_AMBIGUOUS_BINDING", path)
        binding = matches[0]
        if binding.binding_status != "approved":
            raise BindingGateError("BINDING_NOT_APPROVED", path)
        if not all(value.strip() for value in (
            binding.binding_id, binding.binding_version, binding.visual_zone
        )):
            raise BindingGateError("INCOMPLETE_BINDING", path)
        if "desired_zone" in sound and sound["desired_zone"] != binding.visual_zone:
            raise BindingGateError("DESIRED_ZONE_MISMATCH", path)
        resolved.append(binding)
    return SelectedBindings(request, tuple(resolved), catalog.version, binding_index.version)
