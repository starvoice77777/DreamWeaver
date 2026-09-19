"""Portable page-turning recipe checks; no handoff package is needed in CI."""

import hashlib
import importlib.util
import json
import subprocess
import sys
from pathlib import Path

import pytest

from app.schemas.content import SceneTimelineOut

ROOT = Path(__file__).resolve().parents[2]
PRESET_PATH = ROOT / "DreamWeaver/Resources/Mock/handoff_page_v4.json"
PRESET = json.loads(PRESET_PATH.read_text(encoding="utf-8"))
SPEC = importlib.util.spec_from_file_location(
    "page_importer", ROOT / "scripts/import_fire_handoff.py"
)
IMPORTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(IMPORTER)


def test_page_resources_review_provenance_and_backend_fixture_parity():
    backend = ROOT / "server/app/fixtures" / PRESET_PATH.name
    assert PRESET_PATH.read_bytes() == backend.read_bytes()
    assert PRESET["sceneID"] == "a1111111-1111-4111-8111-111111111114"
    assert PRESET["name"] == "翻页入眠"
    assert PRESET["releaseReady"] is False
    assert PRESET["usage"] == "debug_review_only"
    assert len(PRESET["sources"]) == len(
        {source["id"] for source in PRESET["sources"]}
    ) == 11
    assert [source["layer"] for source in PRESET["sources"]] == [
        "environment",
        "ambience",
        "ambience",
        *(["trigger"] * 8),
    ]
    assert all(source["initialEnvelope"] == 1 for source in PRESET["sources"])
    assert sum(source["isEnabled"] for source in PRESET["sources"]) == 3
    assert PRESET["provenance"]["sourceHashes"] == (
        IMPORTER.PAGE_EXPECTED_SOURCE_HASHES
    )
    assert PRESET["provenance"]["assetIndexSHA256"] == (
        IMPORTER.EXPECTED_ASSET_INDEX_HASH
    )
    assert PRESET["provenance"]["releaseBlockers"]
    assert PRESET["loopCrossfades"] == {
        "handoff_room_study_quiet_loop": 500,
        "handoff_air_winter_far_loop": 500,
        "handoff_paper_texture_loop": 500,
    }
    for binding in PRESET["provenance"]["bindings"]:
        audio = ROOT / "DreamWeaver/Resources/Audio" / (
            binding["resourceKey"] + ".m4a"
        )
        assert hashlib.sha256(audio.read_bytes()).hexdigest() == (
            binding["outputSHA256"]
        )
        assert binding["assetStatus"] == "qc_pending"
        assert binding["licenseStatus"] == "pending"


def test_page_importer_pins_all_review_inputs(tmp_path):
    package = tmp_path / "scene_packages" / "sc_page_v01_review"
    timeline = package / "scene/timeline.json"
    timeline.parent.mkdir(parents=True)
    timeline.write_text('{"scene_id":"sc_page_v01","version":4}', encoding="utf-8")

    message = "Unexpected source package SHA-256 for scene/timeline.json"
    with pytest.raises(ValueError, match=message):
        IMPORTER.convert(package)

    asset_index = tmp_path / "audio_asset_index.csv"
    asset_index.write_text("changed", encoding="utf-8")
    message = "Unexpected source package SHA-256 for audio_asset_index.csv"
    with pytest.raises(ValueError, match=message):
        IMPORTER.validated_asset_index(package, IMPORTER.EXPECTED_ASSET_INDEX_HASH)


def test_page_importer_rejects_changed_source_under_optimized_python(tmp_path):
    package = tmp_path / "scene_packages" / "sc_page_v01_review"
    timeline = package / "scene/timeline.json"
    timeline.parent.mkdir(parents=True)
    timeline.write_text('{"scene_id":"sc_page_v01","version":4}', encoding="utf-8")

    result = subprocess.run(
        [sys.executable, "-O", str(ROOT / "scripts/import_fire_handoff.py"), str(package)],
        capture_output=True,
        check=False,
        text=True,
        timeout=10,
    )

    assert result.returncode != 0
    assert "Unexpected source package SHA-256 for scene/timeline.json" in result.stderr


def test_page_cue_times_are_canonical_and_ids_are_unique():
    timeline = SceneTimelineOut.model_validate(PRESET["timeline"])
    assert str(timeline.scene_id) == PRESET["sceneID"]
    assert timeline.version == 4 and timeline.duration_hint_seconds == 250
    assert len(timeline.cues) == 99
    assert len({cue.id for cue in timeline.cues}) == 99
    assert len({cue.at_seconds for cue in timeline.cues}) == 99
    assert sum(len(cue.actions) for cue in timeline.cues) == 355

    computed_end = 238.26 + 10.92
    assert computed_end != 249.18
    assert IMPORTER.cue_time(computed_end) == 249.18
    assert IMPORTER.cue_time(computed_end) == IMPORTER.cue_time(249.18)

    final_trigger_cue = [cue for cue in timeline.cues if cue.at_seconds == 249.18]
    assert len(final_trigger_cue) == 1
    assert [action.type for action in final_trigger_cue[0].actions].count("pause") == 1


def test_page_triggers_are_serial_and_first_fades_start_from_silence():
    timeline = SceneTimelineOut.model_validate(PRESET["timeline"])
    actions = [(cue.at_seconds, action) for cue in timeline.cues for action in cue.actions]
    ids = {source["resourceName"]: source["id"] for source in PRESET["sources"]}
    keys_by_id = {track_id: key for key, track_id in ids.items()}
    triggers = {
        "handoff_page_turn_slow_a": (5, 0.18),
        "handoff_pencil_write_soft_a": (5, 0.16),
        "handoff_cloth_soft_a": (5, 0.16),
        "handoff_page_turn_slow_b": (5, 0.18),
        "handoff_pencil_write_soft_b": (5, 0.16),
        "handoff_cloth_soft_b": (5, 0.16),
        "handoff_water_sip_soft": (6, 0.11),
        "handoff_cookie_chew_optional": (10.92, 0.08),
    }
    shots = [
        (time, str(action.track_id))
        for time, action in actions
        if action.type == "play_oneshot"
    ]
    assert len(shots) == 32
    assert shots[0][0] == 15 and shots[-1][0] == 238.26

    pauses = {
        (time, str(action.track_id))
        for time, action in actions
        if action.type == "pause"
    }
    windows = []
    for start, track_id in shots:
        duration = triggers[keys_by_id[track_id]][0]
        end = IMPORTER.cue_time(start + duration)
        assert (end, track_id) in pauses
        windows.append((start, end))
    adjacent_windows = zip(windows, windows[1:], strict=False)
    assert all(end <= next_start for (_, end), (next_start, _) in adjacent_windows)

    first_shots = {}
    for start, track_id in shots:
        first_shots.setdefault(track_id, start)
    assert len(first_shots) == 8
    for key, (_, target) in triggers.items():
        track_id = ids[key]
        cue = next(cue for cue in timeline.cues if cue.at_seconds == first_shots[track_id])
        track_actions = [
            action for action in cue.actions if str(action.track_id) == track_id
        ]
        envelopes = [
            action for action in track_actions if action.type == "set_envelope"
        ]
        assert [(action.envelope, action.fade_ms) for action in envelopes[-2:]] == [
            (0, 0),
            (target, 350),
        ]
        shot_index = next(
            index
            for index, action in enumerate(track_actions)
            if action.type == "play_oneshot"
        )
        assert track_actions.index(envelopes[-2]) < track_actions.index(envelopes[-1])
        assert track_actions.index(envelopes[-1]) < shot_index
