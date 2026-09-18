"""Portable recipe checks; no untracked handoff package is needed in CI."""

import hashlib
import importlib.util
import json
from pathlib import Path

import pytest

from app.schemas.content import SceneTimelineOut

ROOT = Path(__file__).resolve().parents[2]
PRESET_PATH = ROOT / "DreamWeaver/Resources/Mock/handoff_fireplace_v4.json"
PRESET = json.loads(PRESET_PATH.read_text("utf-8"))
SPEC = importlib.util.spec_from_file_location(
    "fireplace_importer", ROOT / "scripts/import_fire_handoff.py"
)
IMPORTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(IMPORTER)


def test_fireplace_resources_and_review_provenance():
    assert PRESET["sceneID"] == "a1111111-1111-4111-8111-11111111110d"
    assert PRESET["releaseReady"] is False
    assert PRESET["usage"] == "debug_review_only"
    assert len(PRESET["sources"]) == len({s["id"] for s in PRESET["sources"]}) == 5
    assert all(s["initialEnvelope"] == 1 for s in PRESET["sources"])
    assert sum(s["isEnabled"] for s in PRESET["sources"]) == 1
    assert PRESET["provenance"]["releaseBlockers"]
    assert len(PRESET["provenance"]["sourceHashes"]) == 6
    for binding in PRESET["provenance"]["bindings"]:
        path = ROOT / "DreamWeaver/Resources/Audio" / (binding["resourceKey"] + ".m4a")
        assert hashlib.sha256(path.read_bytes()).hexdigest() == binding["outputSHA256"]
        assert binding["assetStatus"] == "qc_pending"
        assert binding["licenseStatus"] == "pending"


def test_fireplace_importer_pins_the_reviewed_source_package(tmp_path):
    assert PRESET["provenance"]["sourceHashes"] == IMPORTER.EXPECTED_SOURCE_HASHES

    package = tmp_path / "sc_fire_v01_review"
    timeline = package / "scene/timeline.json"
    timeline.parent.mkdir(parents=True)
    timeline.write_text('{"scene_id":"sc_fire_v01","version":4}', encoding="utf-8")

    message = "Unexpected source package SHA-256 for scene/timeline.json"
    with pytest.raises(ValueError, match=message):
        IMPORTER.convert(package)


def test_fireplace_runtime_contract_preserves_windows_gains_and_fades():
    timeline = SceneTimelineOut.model_validate(PRESET["timeline"])
    assert str(timeline.scene_id) == PRESET["sceneID"]
    assert timeline.version == 4 and timeline.duration_hint_seconds == 620
    assert not timeline.phrases
    actions = [(c.at_seconds, a) for c in timeline.cues for a in c.actions]
    ids = {s["id"] for s in PRESET["sources"]}
    assert all(str(a.track_id) in ids for _, a in actions)
    assert [t for t, a in actions if a.type == "play"] == [0, 10]
    assert [t for t, a in actions if a.type == "play_oneshot"] == [75, 168, 278, 389, 505]
    stops = [t for t, a in actions if a.type == "pause"]
    assert stops == [80, 172.696, 282.597, 394, 509.696, 620, 620]
    repeats = [(t, a.envelope) for t, a in actions if a.type == "set_envelope" and t in (389, 505)]
    assert repeats == [(389, 0.32), (505, 0.31)]
    assert sum(t == 610 and a.envelope == 0 and a.fade_ms == 10000 for t, a in actions) == 2
    assert PRESET["loopCrossfades"] == {"handoff_room_quiet": 500, "handoff_fire_soft_01": 1000}
