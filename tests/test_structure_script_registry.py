import json
import subprocess
import unittest
from pathlib import Path


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
        self.assertEqual(registry["registry_version"], "1.0.0")
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
            self.assertEqual(result_budget["max_objects"], 4)
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


if __name__ == "__main__":
    unittest.main()
