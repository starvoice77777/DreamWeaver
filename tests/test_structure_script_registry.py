import json
import subprocess
import unittest
from pathlib import Path
from tools import validate_structure_script_registry as validation


ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "docs" / "现行工作集" / "02_辅助创建与视觉框架" / "结构脚本注册表_v1"
REGISTRY = PACKAGE / "script-registry.json"
VALIDATOR = ROOT / "tools" / "validate_structure_script_registry.py"

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

COMMON_PIPELINE = [
    "validate_input",
    "resolve_approved_bindings",
    "assign_structural_slots",
    "apply_framework_state",
    "preserve_manual_overrides",
    "emit_scene_draft",
]

REQUIRED_GLOBAL_GUARDS = {
    "do_not_change_asset_kind",
    "do_not_delete_non_target_objects",
    "do_not_modify_user_locked_objects",
    "do_not_overwrite_manual_tracks_without_confirmation",
    "do_not_emit_arbitrary_cues",
    "do_not_emit_arbitrary_coordinates",
    "do_not_bypass_approved_bindings",
}

REQUIRED_FAMILY_GUARDS = {
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


class StructureScriptRegistryTests(unittest.TestCase):
    def load_registry_and_scripts(self):
        if not REGISTRY.is_file():
            self.fail(f"missing registry: {REGISTRY}")
        registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
        scripts = []
        for item in registry["scripts"]:
            path = PACKAGE / item["path"]
            if not path.is_file():
                self.fail(f"missing script: {path}")
            scripts.append(json.loads(path.read_text(encoding="utf-8")))
        return registry, scripts

    def test_package_passes_executable_validator(self):
        if not VALIDATOR.is_file():
            self.fail(f"missing validator: {VALIDATOR}")
        result = subprocess.run(
            [str(Path(subprocess.sys.executable)), str(VALIDATOR), str(PACKAGE)],
            cwd=ROOT,
            capture_output=True,
            text=True,
            encoding="utf-8",
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("validated 5 structure scripts", result.stdout)

    def test_registry_has_exactly_five_families_in_product_order(self):
        registry, scripts = self.load_registry_and_scripts()
        self.assertEqual(registry["contract_version"], "dreamweaver-structure-script-registry-v1")
        self.assertEqual(registry["registry_version"], "2.0.0")
        self.assertEqual(
            [(s["script_id"], s["framework_id"]) for s in scripts],
            [(script_id, framework_id) for script_id, framework_id, *_ in EXPECTED],
        )
        self.assertEqual(len({s["script_id"] for s in scripts}), 5)

    def test_each_family_uses_the_remote_controller_contract(self):
        _, scripts = self.load_registry_and_scripts()
        for script, (_, _, parameter, value_type, domain) in zip(scripts, EXPECTED, strict=True):
            controller = script["controller"]
            self.assertEqual(controller["parameter"], parameter)
            self.assertEqual(controller["value_type"], value_type)
            if value_type == "number":
                self.assertEqual([controller["minimum"], controller["maximum"]], domain)
            elif value_type == "enum":
                self.assertEqual(controller["allowed_values"], domain)
            else:
                self.assertEqual(controller["max_targets"], 3)

    def test_each_family_enforces_shared_sound_budget_and_manual_protection(self):
        _, scripts = self.load_registry_and_scripts()
        for script in scripts:
            request_budget = script["sound_budget"]["request"]
            result_budget = script["sound_budget"]["compiled_scene"]
            self.assertEqual(request_budget, {"min_objects": 1, "max_objects": 4})
            self.assertEqual(result_budget["min_objects"], 2)
            maximum = 3 if script["framework_id"] in {"enclosure_control", "depth_reveal"} else 4
            self.assertEqual(result_budget["max_objects"], maximum)
            self.assertEqual(script["supplement_policy"]["max_result_objects"], maximum)
            self.assertEqual(result_budget["bed"], {"min": 1, "max": 1})
            self.assertEqual(result_budget["ambience"]["max"], 1)
            self.assertEqual(result_budget["foreground"]["max"], 3)
            self.assertEqual(result_budget["ambience_plus_foreground"], {"min": 1, "max": 3})
            self.assertEqual(script["manual_override_policy"]["mode"], "preserve_by_default")
            self.assertEqual(
                script["manual_override_policy"]["on_conflict"],
                "require_explicit_confirmation",
            )

    def test_compile_pipeline_is_deterministic_and_guards_family_semantics(self):
        _, scripts = self.load_registry_and_scripts()
        for script in scripts:
            self.assertEqual([step["step_id"] for step in script["compile_pipeline"]], COMMON_PIPELINE)
            guards = set(script["safety_rules"])
            self.assertTrue(REQUIRED_GLOBAL_GUARDS.issubset(guards))
            self.assertTrue(REQUIRED_FAMILY_GUARDS[script["script_id"]].issubset(guards))
            self.assertEqual(script["execution_status"], "implementation_ready")
            self.assertEqual(script["review_status"], "pending_listening_review")

    def feasible_counts(self, script):
        return validation.feasible_slot_counts(script)

    def test_boundary_can_reach_four_objects_with_two_inside_details(self):
        _, scripts = self.load_registry_and_scripts()
        self.assertEqual(self.feasible_counts(scripts[0]), {(1, 1, 0), (1, 1, 1), (1, 1, 2)})

    def test_enclosure_accepts_detail_without_surround_and_never_exceeds_three(self):
        _, scripts = self.load_registry_and_scripts()
        self.assertEqual(self.feasible_counts(scripts[1]), {(1, 1, 0), (1, 0, 1), (1, 1, 1)})

    def test_depth_accepts_any_two_distinct_groups_and_at_most_three_objects(self):
        _, scripts = self.load_registry_and_scripts()
        self.assertEqual(self.feasible_counts(scripts[2]), {(1, 1, 0), (1, 0, 1), (0, 1, 1), (1, 1, 1)})

    def test_nearfield_accepts_one_side_or_front_without_forcing_both_sides(self):
        _, scripts = self.load_registry_and_scripts()
        expected = {(1, 1, 0, 0), (1, 0, 1, 0), (1, 0, 0, 1), (1, 1, 1, 0),
                    (1, 1, 0, 1), (1, 0, 1, 1), (1, 1, 1, 1)}
        self.assertEqual(self.feasible_counts(scripts[4]), expected)

    def test_focus_positions_share_one_semantic_zone_and_three_object_budget(self):
        _, scripts = self.load_registry_and_scripts()
        focus = scripts[3]
        self.assertEqual([s["visual_zone"] for s in focus["structural_slots"]], ["base", "focus_field"])
        self.assertEqual(self.feasible_counts(focus), {(1, 1), (1, 2), (1, 3)})

    def test_regions_and_playback_classes_use_one_binding_vocabulary(self):
        _, scripts = self.load_registry_and_scripts()
        expected_zones = [
            ["outside", "inside", "inside"], ["base", "surround", "detail"],
            ["far", "mid", "near"], ["base", "focus_field"],
            ["background", "left_near", "right_near", "front_companion"],
        ]
        for script, zones in zip(scripts, expected_zones):
            with self.subTest(framework=script["framework_id"]):
                self.assertEqual([s["visual_zone"] for s in script["structural_slots"]], zones)
                for slot in script["structural_slots"]:
                    self.assertTrue(set(slot["playback_classes"]) <= {"sustained", "episodic", "continuous_trigger", "voice"})

    def test_supplements_only_supply_the_product_defined_support_layers(self):
        _, scripts = self.load_registry_and_scripts()
        expected = [
            {"outside_environment", "inside_stable"}, {"stable_bed"},
            {"far_sustained"}, {"stable_room_bed"}, {"stable_background"},
        ]
        for script, allowed in zip(scripts, expected):
            self.assertEqual({s["slot_id"] for s in script["structural_slots"] if s["supplement_allowed"]}, allowed)

    def test_validator_rejects_unreachable_advertised_slot_capacity(self):
        _, scripts = self.load_registry_and_scripts()
        scripts[0]["structural_slots"][2]["max_objects"] = 3
        with self.assertRaisesRegex(validation.ValidationFailure, "unreachable slot capacity"):
            validation.validate_slots(scripts[0])

    def test_validator_rejects_unknown_occupancy_slot(self):
        _, scripts = self.load_registry_and_scripts()
        scripts[1]["occupancy_constraints"] = [{"slot_ids": ["missing"], "min_occupied_slots": 1}]
        with self.assertRaisesRegex(validation.ValidationFailure, "unknown occupancy slot"):
            validation.validate_slots(scripts[1])

    def test_validator_rejects_legacy_playback_vocabulary(self):
        _, scripts = self.load_registry_and_scripts()
        scripts[0]["structural_slots"][0]["playback_classes"] = ["bounded_loop"]
        with self.assertRaisesRegex(validation.ValidationFailure, "unknown playback class"):
            validation.validate_slots(scripts[0])

    def test_validator_rejects_negative_capacity(self):
        _, scripts = self.load_registry_and_scripts()
        scripts[0]["structural_slots"][2]["min_objects"] = -1
        with self.assertRaisesRegex(validation.ValidationFailure, "invalid slot capacity"):
            validation.validate_slots(scripts[0])

    def test_role_budget_blocks_two_voices_or_two_ambiences_even_with_free_slots(self):
        _, scripts = self.load_registry_and_scripts()
        focus = scripts[3]
        for role in ("voice", "ambience"):
            with self.subTest(role=role):
                focus["structural_slots"][1]["allowed_roles"] = [role]
                self.assertEqual(self.feasible_counts(focus), {(1, 1)})

    def test_cross_slot_constraint_can_reject_an_otherwise_valid_role_budget(self):
        _, scripts = self.load_registry_and_scripts()
        depth = scripts[2]
        depth["structural_slots"][0]["max_objects"] = 2
        self.assertNotIn((2, 0, 0), self.feasible_counts(depth))


if __name__ == "__main__":
    unittest.main()
