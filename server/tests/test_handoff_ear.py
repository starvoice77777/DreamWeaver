"""Portable ear-care recipe checks; no untracked handoff package is needed in CI."""

import hashlib
import importlib.util
import json
from pathlib import Path

import pytest

from app.schemas.content import SceneTimelineOut

ROOT = Path(__file__).resolve().parents[2]
PRESET_PATH = ROOT / "DreamWeaver/Resources/Mock/handoff_ear_v4.json"
PRESET = json.loads(PRESET_PATH.read_text(encoding="utf-8"))
SPEC = importlib.util.spec_from_file_location(
    "ear_importer", ROOT / "scripts/import_fire_handoff.py"
)
IMPORTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(IMPORTER)


def test_ear_resources_review_provenance_and_backend_fixture_parity():
    backend = ROOT / "server/app/fixtures" / PRESET_PATH.name
    assert PRESET_PATH.read_bytes() == backend.read_bytes()
    assert PRESET["sceneID"] == "a1111111-1111-4111-8111-111111111113"
    assert PRESET["name"] == "采耳 ASMR"
    assert PRESET["releaseReady"] is False
    assert PRESET["usage"] == "debug_review_only"
    assert len(PRESET["sources"]) == len({source["id"] for source in PRESET["sources"]}) == 6
    assert [source["layer"] for source in PRESET["sources"]] == [
        "environment",
        "trigger",
        "trigger",
        "trigger",
        "trigger",
        "trigger",
    ]
    assert all(source["initialEnvelope"] == 1 for source in PRESET["sources"])
    assert sum(source["isEnabled"] for source in PRESET["sources"]) == 2
    assert PRESET["provenance"]["sourceHashes"] == IMPORTER.EAR_EXPECTED_SOURCE_HASHES
    assert PRESET["provenance"]["assetIndexSHA256"] == IMPORTER.EXPECTED_ASSET_INDEX_HASH
    assert PRESET["provenance"]["releaseBlockers"]
    assert "known 62-character SHA-256 typo" in PRESET["provenance"]["notes"][0]
    assert PRESET["loopCrossfades"] == {"handoff_room_earcare_quiet_loop": 500}
    for binding in PRESET["provenance"]["bindings"]:
        audio = ROOT / "DreamWeaver/Resources/Audio" / (binding["resourceKey"] + ".m4a")
        assert hashlib.sha256(audio.read_bytes()).hexdigest() == binding["outputSHA256"]
        assert binding["assetStatus"] == "qc_pending"
        assert binding["licenseStatus"] == "pending"


def test_ear_importer_pins_all_review_inputs(tmp_path):
    package = tmp_path / "scene_packages" / "sc_ear_v01_review"
    timeline = package / "scene/timeline.json"
    timeline.parent.mkdir(parents=True)
    timeline.write_text('{"scene_id":"sc_ear_v01","version":4}', encoding="utf-8")

    message = "Unexpected source package SHA-256 for scene/timeline.json"
    with pytest.raises(ValueError, match=message):
        IMPORTER.convert(package)

    asset_index = tmp_path / "audio_asset_index.csv"
    asset_index.write_text("changed", encoding="utf-8")
    message = "Unexpected source package SHA-256 for audio_asset_index.csv"
    with pytest.raises(ValueError, match=message):
        IMPORTER.validated_asset_index(package, IMPORTER.EXPECTED_ASSET_INDEX_HASH)


def test_ear_goose_feather_exception_is_exact_and_still_binds_the_real_master():
    reported = IMPORTER.EAR_SOURCE_MAP_SHA_EXCEPTIONS["ear_goose_feather_01"]
    binding = next(
        item
        for item in PRESET["provenance"]["bindings"]
        if item["sourceResourceKey"] == "ear_goose_feather_01"
    )
    assert len(reported) == 62
    assert reported == "cb0e1b94b40bef362f14cb024e20bad8818f3694726d761d1be6a0c13f177b"
    assert binding["sourceSHA256"] == (
        "cb0e1b94b40bef362f14cb024e20bad8818f3694726d2d761d1be6a0c13f177b"
    )


def test_ear_cues_keep_serial_shots_and_initialize_first_fades_from_silence():
    timeline = SceneTimelineOut.model_validate(PRESET["timeline"])
    assert str(timeline.scene_id) == PRESET["sceneID"]
    assert timeline.version == 4 and timeline.duration_hint_seconds == 600
    assert len(timeline.cues) == 48
    assert sum(len(cue.actions) for cue in timeline.cues) == 244
    actions = [(cue.at_seconds, action) for cue in timeline.cues for action in cue.actions]
    ids = {source["resourceName"]: source["id"] for source in PRESET["sources"]}
    shot_times = [time for time, action in actions if action.type == "play_oneshot"]
    assert shot_times == [0, *range(160, 600, 20)]

    first_fades = [
        ("handoff_ear_cotton_swab_long", 0, 0.24),
        ("handoff_ear_goose_feather", 160, 0.3),
        ("handoff_ear_soft_brush", 180, 0.28),
        ("handoff_ear_sponge_press", 200, 0.26),
        ("handoff_ear_pick_soft", 220, 0.25),
    ]
    for key, start, target in first_fades:
        track_id = ids[key]
        cue = next(cue for cue in timeline.cues if cue.at_seconds == start)
        track_actions = [action for action in cue.actions if str(action.track_id) == track_id]
        envelopes = [action for action in track_actions if action.type == "set_envelope"]
        assert [(action.envelope, action.fade_ms) for action in envelopes[-2:]] == [
            (0, 0),
            (target, 350),
        ]
        shot_index = next(
            index for index, action in enumerate(track_actions) if action.type == "play_oneshot"
        )
        assert track_actions.index(envelopes[-2]) < track_actions.index(envelopes[-1]) < shot_index

    trigger_ids = set(ids.values()) - {ids["handoff_room_earcare_quiet_loop"]}
    zero_starts = [
        time
        for time, action in actions
        if str(action.track_id) in trigger_ids
        and action.type == "set_envelope"
        and action.envelope == 0
        and action.fade_ms == 0
    ]
    assert zero_starts == [0, 160, 180, 200, 220]
