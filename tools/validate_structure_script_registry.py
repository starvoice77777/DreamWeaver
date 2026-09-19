#!/usr/bin/env python3
"""Validate DreamWeaver's versioned five-family structure-script package."""

from __future__ import annotations

import itertools
import json
import re
import sys
from pathlib import Path
from typing import Any


EXPECTED = [
    ("boundary_gate_script", "boundary_gate", "boundary_openness", "number", [0, 1]),
    (
        "enclosure_control_script",
        "enclosure_control",
        "enclosure_level",
        "enum",
        ["open", "balanced", "enclosed"],
    ),
    (
        "depth_reveal_script",
        "depth_reveal",
        "depth_reveal",
        "enum",
        ["near", "balanced", "far"],
    ),
    ("focus_selector_script", "focus_selector", "focus_target", "sound_object_id", None),
    (
        "nearfield_width_script",
        "nearfield_width",
        "nearfield_width",
        "enum",
        ["focused", "natural", "wide"],
    ),
]

REQUIRED_SCRIPT_KEYS = {
    "contract_version",
    "script_id",
    "script_version",
    "framework_id",
    "product_name",
    "description",
    "execution_status",
    "review_status",
    "controller",
    "sound_budget",
    "structural_slots",
    "occupancy_constraints",
    "state_resolution",
    "compile_pipeline",
    "safety_rules",
    "manual_override_policy",
    "supplement_policy",
    "output_contract",
    "acceptance",
}

PIPELINE = [
    "validate_input",
    "resolve_approved_bindings",
    "assign_structural_slots",
    "apply_framework_state",
    "preserve_manual_overrides",
    "emit_scene_draft",
]

GLOBAL_GUARDS = {
    "do_not_change_asset_kind",
    "do_not_delete_non_target_objects",
    "do_not_modify_user_locked_objects",
    "do_not_overwrite_manual_tracks_without_confirmation",
    "do_not_emit_arbitrary_cues",
    "do_not_emit_arbitrary_coordinates",
    "do_not_bypass_approved_bindings",
}

FAMILY_GUARDS = {
    "boundary_gate_script": {
        "preserve_event_schedule",
        "preserve_motion_paths",
        "outside_group_never_hard_mutes",
    },
    "enclosure_control_script": {
        "preserve_active_oneshots",
        "future_events_only_for_density_changes",
        "approved_motion_profiles_only",
    },
    "depth_reveal_script": {
        "preserve_scene_roles",
        "preserve_event_frequency",
        "approved_distance_profiles_only",
    },
    "focus_selector_script": {
        "retain_non_focused_objects",
        "do_not_trigger_oneshot_on_focus_change",
        "future_events_only_for_trigger_bias",
    },
    "nearfield_width_script": {
        "preserve_trigger_frequency",
        "apply_at_next_event_or_safe_boundary",
        "approved_nearfield_motion_profiles_only",
    },
}

VERSION_RE = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")
ALLOWED_ROLES = {"bed", "ambience", "action", "trigger", "voice"}
PLAYBACK_CLASSES = {"sustained", "episodic", "continuous_trigger", "voice"}
FRAMEWORK_MAXIMUM = {"boundary_gate": 4, "enclosure_control": 3, "depth_reveal": 3, "focus_selector": 4, "nearfield_width": 4}
FORBIDDEN_SCRIPT_KEYS = {"cues", "at_seconds", "angle", "radius", "default_volume", "resource_key"}


class ValidationFailure(Exception):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValidationFailure(message)


def load_json(path: Path) -> dict[str, Any]:
    require(path.is_file(), f"missing file: {path}")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValidationFailure(f"invalid JSON: {path}: {exc}") from exc
    require(isinstance(value, dict), f"top-level JSON must be an object: {path}")
    return value


def walk_keys(value: Any) -> set[str]:
    keys: set[str] = set()
    if isinstance(value, dict):
        for key, item in value.items():
            keys.add(key)
            keys.update(walk_keys(item))
    elif isinstance(value, list):
        for item in value:
            keys.update(walk_keys(item))
    return keys


def validate_budget(script: dict[str, Any]) -> None:
    budget = script["sound_budget"]
    require(budget["request"] == {"min_objects": 1, "max_objects": 4}, "request budget must be 1..4")
    compiled = budget["compiled_scene"]
    maximum = FRAMEWORK_MAXIMUM[script["framework_id"]]
    require(compiled["min_objects"] == 2 and compiled["max_objects"] == maximum, "compiled budget must match framework product limit")
    require(compiled["bed"] == {"min": 1, "max": 1}, "compiled scene must contain exactly one bed")
    require(compiled["ambience"] == {"min": 0, "max": 1}, "compiled scene allows zero or one ambience object")
    require(compiled["foreground"] == {"min": 0, "max": 3}, "compiled scene allows zero to three foreground objects")
    require(compiled["ambience_plus_foreground"] == {"min": 1, "max": 3}, "supporting object budget must be 1..3")
    require(compiled["voice_max"] == 1, "compiled scene allows at most one voice object")


def validate_slots(script: dict[str, Any]) -> None:
    slots = script["structural_slots"]
    require(isinstance(slots, list) and 2 <= len(slots) <= 4, "each script needs 2..4 structural slots")
    ids = [slot["slot_id"] for slot in slots]
    require(len(ids) == len(set(ids)), "slot_id values must be unique")
    priorities = [slot["assignment_priority"] for slot in slots]
    require(priorities == sorted(priorities) and len(priorities) == len(set(priorities)), "slot priorities must be unique and ascending")
    for slot in slots:
        minimum, maximum = slot["min_objects"], slot["max_objects"]
        require(type(minimum) is int and type(maximum) is int and 0 <= minimum <= maximum <= 3 and maximum > 0,
                f"invalid slot capacity: {slot['slot_id']}")
        roles = slot["allowed_roles"]
        require(bool(roles) and len(set(roles)) == len(roles) and set(roles) <= ALLOWED_ROLES,
                f"unknown or duplicate role in slot: {slot['slot_id']}")
        classes = slot["playback_classes"]
        require(bool(classes) and len(set(classes)) == len(classes) and set(classes) <= PLAYBACK_CLASSES,
                f"unknown playback class in slot: {slot['slot_id']}")
        require(slot["required_for_playable"] is (minimum > 0), f"required flag disagrees with minimum: {slot['slot_id']}")
    constraints = script["occupancy_constraints"]
    require(isinstance(constraints, list), "occupancy constraints must be an array")
    for rule in constraints:
        targets = rule["slot_ids"]
        require(isinstance(targets, list) and bool(targets) and set(targets) <= set(ids), "unknown occupancy slot")
        require(len(targets) == len(set(targets)), "duplicate occupancy slot")
        minimum = rule["min_occupied_slots"]
        require(type(minimum) is int and 1 <= minimum <= len(targets), "invalid occupied slot minimum")
    feasible = feasible_slot_counts(script)
    require(bool(feasible), "no playable slot and role assignment")
    budget = script["sound_budget"]["compiled_scene"]
    totals = {sum(counts) for counts in feasible}
    require(budget["min_objects"] in totals and budget["max_objects"] in totals, "unreachable compiled object bound")
    for position, slot in enumerate(slots):
        require(any(counts[position] == slot["max_objects"] for counts in feasible),
                f"unreachable slot capacity: {slot['slot_id']}")


def feasible_slot_counts(script: dict[str, Any]) -> set[tuple[int, ...]]:
    """Check declarative feasibility, not approval of any concrete audio resource."""
    slots = script["structural_slots"]
    budget = script["sound_budget"]["compiled_scene"]
    feasible = set()
    domains = [range(slot["min_objects"], slot["max_objects"] + 1) for slot in slots]
    for counts in itertools.product(*domains):
        if not budget["min_objects"] <= sum(counts) <= budget["max_objects"]:
            continue
        occupied = {slot["slot_id"] for slot, count in zip(slots, counts) if count}
        if any(len(occupied.intersection(rule["slot_ids"])) < rule["min_occupied_slots"]
               for rule in script["occupancy_constraints"]):
            continue
        role_domains = [slot["allowed_roles"] for slot, count in zip(slots, counts) for _ in range(count)]
        for roles in itertools.product(*role_domains):
            values = {
                "bed": roles.count("bed"), "ambience": roles.count("ambience"),
                "foreground": sum(roles.count(role) for role in ("action", "trigger", "voice")),
                "ambience_plus_foreground": len(roles) - roles.count("bed"),
            }
            if roles.count("voice") <= budget["voice_max"] and all(
                budget[key]["min"] <= value <= budget[key]["max"] for key, value in values.items()
            ):
                feasible.add(counts)
                break
    return feasible


def validate_controller(script: dict[str, Any], expected: tuple[Any, ...]) -> None:
    _, _, parameter, value_type, domain = expected
    controller = script["controller"]
    require(controller["parameter"] == parameter, f"wrong controller parameter for {script['script_id']}")
    require(controller["value_type"] == value_type, f"wrong controller type for {script['script_id']}")
    if value_type == "number":
        require([controller.get("minimum"), controller.get("maximum")] == domain, "boundary range must be 0..1")
    elif value_type == "enum":
        require(controller.get("allowed_values") == domain, f"wrong enum domain for {script['script_id']}")
        require(controller["default_value"] in domain, f"default state is outside enum for {script['script_id']}")
    else:
        require(controller.get("max_targets") == 3, "focus selector must allow at most three targets")


def validate_script(script: dict[str, Any], item: dict[str, Any], expected: tuple[Any, ...]) -> None:
    missing = REQUIRED_SCRIPT_KEYS - set(script)
    require(not missing, f"{item['path']} missing keys: {sorted(missing)}")
    script_id, framework_id, *_ = expected
    require(script["contract_version"] == "dreamweaver-structure-script-v2", f"wrong contract in {script_id}")
    require(script["script_id"] == item["script_id"] == script_id, f"script id mismatch: {item['path']}")
    require(script["framework_id"] == item["framework_id"] == framework_id, f"framework mismatch: {script_id}")
    require(script["script_version"] == item["script_version"], f"version mismatch: {script_id}")
    require(bool(VERSION_RE.fullmatch(script["script_version"])), f"invalid semantic version: {script_id}")
    require(script["product_name"] == item["product_name"], f"product name mismatch: {script_id}")
    require(script["execution_status"] == "implementation_ready", f"script is not executable: {script_id}")
    require(script["review_status"] in {"pending_listening_review", "approved", "rejected"}, f"invalid review status: {script_id}")
    validate_controller(script, expected)
    validate_budget(script)
    validate_slots(script)
    pipeline = script["compile_pipeline"]
    require([step["step_id"] for step in pipeline] == PIPELINE, f"wrong compile pipeline: {script_id}")
    require(all(step.get("processor") and step.get("on_failure") for step in pipeline), f"incomplete compile step: {script_id}")
    guards = set(script["safety_rules"])
    require(GLOBAL_GUARDS <= guards, f"missing global safety rule: {script_id}")
    require(FAMILY_GUARDS[script_id] <= guards, f"missing family safety rule: {script_id}")
    manual = script["manual_override_policy"]
    require(manual["mode"] == "preserve_by_default", f"manual tracks are not protected: {script_id}")
    require(manual["on_conflict"] == "require_explicit_confirmation", f"manual conflict must require confirmation: {script_id}")
    require(manual["no_implicit_override"] is True, f"implicit override must be disabled: {script_id}")
    supplement = script["supplement_policy"]
    require(supplement["origin"] == "system_supplement" and supplement["requires_reason"] is True, f"supplements must be explicit: {script_id}")
    require(supplement["max_result_objects"] == script["sound_budget"]["compiled_scene"]["max_objects"]
            and supplement["readd_user_deleted"] is False, f"invalid supplement budget: {script_id}")
    output = script["output_contract"]
    require(output["cue_authority"] == "deterministic_timeline_compiler", f"AI cannot own cues: {script_id}")
    require("script" in output["required_dependency_versions"], f"script version missing from dependencies: {script_id}")
    require(script["state_resolution"].get("rules"), f"state resolution rules missing: {script_id}")
    forbidden = FORBIDDEN_SCRIPT_KEYS & walk_keys(script)
    require(not forbidden, f"script embeds compiler-owned fields {sorted(forbidden)}: {script_id}")


def validate_package(package: Path) -> int:
    schema = load_json(package / "structure-script.schema.json")
    require(schema.get("$schema") == "https://json-schema.org/draft/2020-12/schema", "schema must use draft 2020-12")
    registry = load_json(package / "script-registry.json")
    require(registry.get("contract_version") == "dreamweaver-structure-script-registry-v1", "wrong registry contract")
    require(bool(VERSION_RE.fullmatch(registry.get("registry_version", ""))), "invalid registry version")
    items = registry.get("scripts")
    require(isinstance(items, list) and len(items) == 5, "registry must contain exactly five scripts")
    require([item.get("order") for item in items] == [1, 2, 3, 4, 5], "registry order must be 1..5")
    require(len({item.get("script_id") for item in items}) == 5, "script ids must be unique")
    for item, expected in zip(items, EXPECTED, strict=True):
        path = package / item["path"]
        try:
            path.resolve().relative_to(package.resolve())
        except ValueError as exc:
            raise ValidationFailure(f"script path escapes package: {item['path']}") from exc
        validate_script(load_json(path), item, expected)
    return len(items)


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: validate_structure_script_registry.py <package-directory>", file=sys.stderr)
        return 2
    try:
        count = validate_package(Path(argv[1]))
    except (KeyError, TypeError, ValidationFailure) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    print(f"validated {count} structure scripts")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
