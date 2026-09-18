"""Portable mist recipe checks; no untracked handoff package is needed in CI."""

import hashlib
import importlib.util
import json
from pathlib import Path

import pytest

from app.schemas.content import SceneTimelineOut

ROOT = Path(__file__).resolve().parents[2]
PRESET_PATH = ROOT / "DreamWeaver/Resources/Mock/handoff_mist_v4.json"
PRESET = json.loads(PRESET_PATH.read_text(encoding="utf-8"))
SPEC = importlib.util.spec_from_file_location(
    "mist_importer", ROOT / "scripts/import_fire_handoff.py"
)
IMPORTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(IMPORTER)


def test_mist_resources_review_provenance_and_backend_fixture_parity():
    backend = ROOT / "server/app/fixtures" / PRESET_PATH.name
    assert PRESET_PATH.read_bytes() == backend.read_bytes()
    assert PRESET["sceneID"] == "a1111111-1111-4111-8111-111111111104"
    assert PRESET["name"] == "雾海缓潮"
    assert PRESET["releaseReady"] is False
    assert PRESET["usage"] == "debug_review_only"
    assert len(PRESET["sources"]) == len({source["id"] for source in PRESET["sources"]}) == 6
    assert [source["layer"] for source in PRESET["sources"]] == [
        "environment",
        "environment",
        "ambience",
        "ambience",
        "trigger",
        "trigger",
    ]
    assert all(source["initialEnvelope"] == 1 for source in PRESET["sources"])
    assert sum(source["isEnabled"] for source in PRESET["sources"]) == 3
    assert PRESET["provenance"]["sourceHashes"] == IMPORTER.MIST_EXPECTED_SOURCE_HASHES
    assert PRESET["provenance"]["releaseBlockers"]
    assert "465" in PRESET["provenance"]["notes"][0]
    for binding in PRESET["provenance"]["bindings"]:
        audio = ROOT / "DreamWeaver/Resources/Audio" / (binding["resourceKey"] + ".m4a")
        assert hashlib.sha256(audio.read_bytes()).hexdigest() == binding["outputSHA256"]
        assert binding["assetStatus"] == "qc_pending"
        assert binding["licenseStatus"] == "pending"
    assert PRESET["loopCrossfades"] == {
        "handoff_ocean_bed_soft": 1200,
        "handoff_sea_wind_soft": 500,
        "handoff_shore_water_soft": 750,
        "handoff_boat_water_lap": 750,
    }


def test_mist_importer_pins_the_reviewed_source_package(tmp_path):
    package = tmp_path / "sc_mist_v01_review"
    timeline = package / "scene/timeline.json"
    timeline.parent.mkdir(parents=True)
    timeline.write_text('{"scene_id":"sc_mist_v01","version":4}', encoding="utf-8")

    message = "Unexpected source package SHA-256 for scene/timeline.json"
    with pytest.raises(ValueError, match=message):
        IMPORTER.convert(package)


def test_mist_cues_keep_all_shots_and_the_thirty_second_water_handoff():
    timeline = SceneTimelineOut.model_validate(PRESET["timeline"])
    assert str(timeline.scene_id) == PRESET["sceneID"]
    assert timeline.duration_hint_seconds == 600
    assert timeline.version == 4
    assert not timeline.phrases
    actions = [(cue.at_seconds, action) for cue in timeline.cues for action in cue.actions]
    ids = {source["resourceName"]: source["id"] for source in PRESET["sources"]}
    assert all(str(action.track_id) in ids.values() for _, action in actions)
    assert [time for time, action in actions if action.type == "play_oneshot"] == [
        105,
        220,
        335,
        405,
        465,
        475,
        535,
    ]
    for start, shot in [item for item in actions if item[1].type == "play_oneshot"]:
        assert any(
            time == start + 5 and action.type == "pause" and action.track_id == shot.track_id
            for time, action in actions
        )
    for key, start, end in [
        ("handoff_ocean_bed_soft", 0, 600),
        ("handoff_sea_wind_soft", 0, 600),
        ("handoff_shore_water_soft", 0, 330),
        ("handoff_boat_water_lap", 300, 600),
    ]:
        plays = [
            time
            for time, action in actions
            if str(action.track_id) == ids[key] and action.type == "play"
        ]
        pauses = [
            time
            for time, action in actions
            if str(action.track_id) == ids[key] and action.type == "pause"
        ]
        assert plays == [start]
        assert pauses == [end]
    transition = {
        (str(action.track_id), action.envelope, action.fade_ms)
        for time, action in actions
        if time == 300 and action.type == "set_envelope"
    }
    assert (ids["handoff_shore_water_soft"], 0, 30000) in transition
    assert (ids["handoff_boat_water_lap"], 0.3, 30000) in transition
    positions = {
        (time, action.angle, action.radius)
        for time, action in actions
        if str(action.track_id) == ids["handoff_shore_water_soft"] and action.type == "set_position"
    }
    assert positions == {
        (0, -1.05, 0.92),
        (90, -0.65, 0.92),
        (180, -0.1, 0.93),
        (270, 0.5, 0.95),
        (330, 0.95, 0.98),
    }
