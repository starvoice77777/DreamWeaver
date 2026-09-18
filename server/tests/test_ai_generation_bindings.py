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
    resolve_selected_bindings,
)


@pytest.fixture
def registry_case():
    # Synthetic approvals test the gate; these are not production assets.
    payload = json.loads((Path(__file__).parent / "fixtures" /
                          "ai_generation_request_boundary_rain.json").read_text(encoding="utf-8"))
    asset = CatalogAsset("fixture_rain_main_soft", "master", "approved", "approved")
    binding = FrameBinding("fixture-binding", "fixture-1", asset.resource_key,
                           "boundary_gate", "outside", "approved")
    return payload, AssetCatalog("fixture-1", (asset,)), FrameBindingIndex("fixture-1", (binding,))


def test_approved_selection_is_deterministic_preserves_intent_and_does_not_alias(registry_case):
    payload, catalog, index = registry_case
    original = copy.deepcopy(payload)
    result = resolve_selected_bindings(payload, catalog=catalog, binding_index=index)
    assert result == resolve_selected_bindings(payload, catalog=catalog, binding_index=index)
    assert result.request == original
    assert result.bindings == index.bindings
    assert result.catalog_version == result.binding_index_version == "fixture-1"
    result.request["selected_sounds"][0]["user_locked"] = False
    assert payload == original
    updated = resolve_selected_bindings(payload, catalog=replace(catalog, version="fixture-2"),
                                        binding_index=replace(index, version="fixture-3"))
    assert (updated.catalog_version, updated.binding_index_version) == ("fixture-2", "fixture-3")


@pytest.mark.parametrize("field,status", [
    ("asset_status", "planned"), ("asset_status", "ref"), ("asset_status", "qc_pending"),
    ("license_status", "pending"), ("license_status", "not_required"),
    ("qc_status", "pending"), ("qc_status", ""),
])
def test_asset_requires_master_license_and_qc_approval(registry_case, field, status):
    payload, catalog, index = registry_case
    catalog = replace(catalog, assets=(replace(catalog.assets[0], **{field: status}),))
    with pytest.raises(BindingGateError, match="ASSET_NOT_APPROVED"):
        resolve_selected_bindings(payload, catalog=catalog, binding_index=index)


@pytest.mark.parametrize("status", ["draft", "listening", "rejected", "", "unknown"])
@pytest.mark.parametrize("locked", [True, False])
def test_unapproved_binding_never_replaces_selected_sound(registry_case, status, locked):
    payload, catalog, index = registry_case
    payload["selected_sounds"][0]["user_locked"] = locked
    original = copy.deepcopy(payload)
    index = replace(index, bindings=(replace(index.bindings[0], binding_status=status),))
    with pytest.raises(BindingGateError) as caught:
        resolve_selected_bindings(payload, catalog=catalog, binding_index=index)
    assert caught.value.code == "NO_APPROVED_BINDING"
    assert caught.value.reason_code == "BINDING_NOT_APPROVED"
    assert caught.value.path == ("selected_sounds", 0)
    assert payload == original


@pytest.mark.parametrize("kind", ["asset", "binding"])
@pytest.mark.parametrize("count", [0, 2])
def test_missing_and_duplicate_records_fail_closed(registry_case, kind, count):
    payload, catalog, index = registry_case
    if kind == "asset":
        catalog = replace(catalog, assets=catalog.assets * count)
    else:
        index = replace(index, bindings=index.bindings * count)
    with pytest.raises(BindingGateError, match=f"MISSING_OR_AMBIGUOUS_{kind.upper()}"):
        resolve_selected_bindings(payload, catalog=catalog, binding_index=index)


@pytest.mark.parametrize("field,value,reason", [
    ("resource_key", "fixture_other", "MISSING_OR_AMBIGUOUS_BINDING"),
    ("framework_id", "depth_reveal", "MISSING_OR_AMBIGUOUS_BINDING"),
    ("binding_id", " ", "INCOMPLETE_BINDING"),
    ("binding_version", "", "INCOMPLETE_BINDING"),
    ("visual_zone", "", "INCOMPLETE_BINDING"),
    ("visual_zone", "inside", "DESIRED_ZONE_MISMATCH"),
])
def test_binding_identity_version_and_zone_are_not_guessed(registry_case, field, value, reason):
    payload, catalog, index = registry_case
    index = replace(index, bindings=(replace(index.bindings[0], **{field: value}),))
    with pytest.raises(BindingGateError, match=reason):
        resolve_selected_bindings(payload, catalog=catalog, binding_index=index)


@pytest.mark.parametrize("dependency", ["catalog", "index"])
def test_missing_dependency_version_is_rejected(registry_case, dependency):
    payload, catalog, index = registry_case
    catalog = replace(catalog, version=" ") if dependency == "catalog" else catalog
    index = replace(index, version="") if dependency == "index" else index
    with pytest.raises(BindingGateError, match="MISSING_DEPENDENCY_VERSION"):
        resolve_selected_bindings(payload, catalog=catalog, binding_index=index)


def test_exclusion_and_request_schema_cannot_be_bypassed(registry_case):
    payload, catalog, index = registry_case
    key = payload["selected_sounds"][0]["resource_key"]
    payload["excluded_resource_keys"].append(key)
    with pytest.raises(BindingGateError, match="SELECTED_RESOURCE_EXCLUDED") as caught:
        resolve_selected_bindings(payload, catalog=catalog, binding_index=index)
    assert key not in str(caught.value)
    payload["selected_sounds"] = []
    with pytest.raises(GenerationRequestError, match="INVALID_REQUEST"):
        resolve_selected_bindings(payload, catalog=catalog, binding_index=index)


def test_every_selection_is_checked_in_user_order_without_auto_supplements(registry_case):
    payload, catalog, index = registry_case
    payload["selected_sounds"].append({"sound_object_id": "sound-room",
                                       "resource_key": "fixture_room", "user_locked": False})
    room_asset = replace(catalog.assets[0], resource_key="fixture_room")
    room_binding = replace(index.bindings[0], binding_id="fixture-room-binding",
                           resource_key="fixture_room", visual_zone="inside")
    catalog = replace(catalog, assets=(room_asset, *catalog.assets))
    with pytest.raises(BindingGateError) as caught:
        resolve_selected_bindings(payload, catalog=catalog, binding_index=index)
    assert caught.value.path == ("selected_sounds", 1)
    index = replace(index, bindings=(room_binding, *index.bindings))
    result = resolve_selected_bindings(payload, catalog=catalog, binding_index=index)
    assert [b.resource_key for b in result.bindings] == ["fixture_rain_main_soft", "fixture_room"]
    assert result.request == payload
    assert "desired_zone" not in result.request["selected_sounds"][1]


def test_duplicate_binding_cannot_be_hidden_by_an_unapproved_status(registry_case):
    payload, catalog, index = registry_case
    index = replace(index, bindings=(*index.bindings,
                                     replace(index.bindings[0], binding_status="draft")))
    with pytest.raises(BindingGateError, match="MISSING_OR_AMBIGUOUS_BINDING"):
        resolve_selected_bindings(payload, catalog=catalog, binding_index=index)
