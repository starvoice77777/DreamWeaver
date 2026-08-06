"""Map the sc_hair_wash_v05 review package to the app timeline contract."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
PKG = (
    ROOT
    / "docs/scenes/sc_hair/packages/sc_hair_wash_v05_review/scene/timeline.json"
)
SERVER_OUT = ROOT / "server/app/fixtures/hair_care_timeline_v11.json"
IOS_OUT = ROOT / "DreamWeaver/Resources/Mock/hair_care_timeline_v11.json"
IOS_AUDIO = ROOT / "DreamWeaver/Resources/Audio"

SCENE_ID = "a1111111-1111-4111-8111-111111111101"
VOICE_TRACK_ID = "e5555555-5555-4555-8555-555555555503"
TRACK_MAP = {
    "3c6c0188-1f35-57b6-adbd-1041997e6c91": "e5555555-5555-4555-8555-555555555508",
    "a8f15c0f-c610-51c9-ba22-81e33c5856f6": "e5555555-5555-4555-8555-555555555509",
    "94054d67-d558-5f60-90b4-5370ec3b73fc": "e5555555-5555-4555-8555-55555555550a",
    "ac3556b2-8b76-5cd1-8468-66f691f428da": "e5555555-5555-4555-8555-55555555550b",
    "8c298978-b530-5d36-be43-dc85e5454e0d": "e5555555-5555-4555-8555-55555555550c",
    "9696d138-6fb3-5941-beb2-42075a5d83cb": "e5555555-5555-4555-8555-55555555550d",
    "8cfbe72f-83c1-56af-b744-ed5cee179aa8": "e5555555-5555-4555-8555-55555555550e",
    "f5bc37e9-6721-5ef5-bf29-daa5327aea59": "e5555555-5555-4555-8555-55555555550f",
    "798599d3-a11c-544e-a73e-81519276cb9d": "e5555555-5555-4555-8555-555555555506",
}
ACTION_FIELDS = {
    "type",
    "phrase_id",
    "track_id",
    "envelope",
    "fade_ms",
    "angle",
    "radius",
    "resource_key",
}


def normalize_number(value: float) -> float | int:
    number = float(value)
    if number.is_integer():
        return int(number)
    return number


def build() -> dict[str, Any]:
    pkg = json.loads(PKG.read_text(encoding="utf-8"))
    if pkg.get("scene_id") != "sc_hair_wash_v05" or pkg.get("version") != 11:
        raise ValueError("Unexpected hair-wash source package")

    tracks = {track["track_id"]: track for track in pkg["tracks"]}
    voice_track_ids = {
        track_id for track_id, track in tracks.items() if track["layer"] == "voice"
    }
    if len(tracks) != 29 or len(voice_track_ids) != 20:
        raise ValueError("Expected 9 non-voice tracks and 20 voice tracks")

    complete_track_map = dict(TRACK_MAP)
    complete_track_map.update({track_id: VOICE_TRACK_ID for track_id in voice_track_ids})
    if set(complete_track_map) != set(tracks):
        raise ValueError("TRACK_MAP is out of sync with the review package")

    missing_audio = [
        track["resource_key"]
        for track in tracks.values()
        if not (IOS_AUDIO / f"{track['resource_key']}.wav").is_file()
    ]
    if missing_audio:
        raise FileNotFoundError(f"Missing curated audio resources: {missing_audio}")

    phrases = []
    for phrase in pkg["phrases"]:
        source_track = tracks[phrase["track_id"]]
        phrases.append(
            {
                "id": phrase["phrase_id"],
                "text": phrase["text"],
                "review_status": phrase["review_status"],
                "voice_binding": {
                    "kind": "official_resource",
                    "resource_key": source_track["resource_key"],
                    "track_id": VOICE_TRACK_ID,
                    "track_layer": "voice",
                },
            }
        )

    cues = []
    for cue in pkg["cues"]:
        actions = []
        for raw in cue["actions"]:
            action = {key: value for key, value in raw.items() if key in ACTION_FIELDS}
            if action["type"] == "set_volume":
                action["type"] = "set_envelope"
                action["envelope"] = raw["volume"]
            if "track_id" in action:
                action["track_id"] = complete_track_map[action["track_id"]]
            actions.append(action)
        cues.append(
            {
                "id": cue["id"],
                "at_seconds": normalize_number(cue["at_seconds"]),
                "actions": actions,
            }
        )

    return {
        "scene_id": SCENE_ID,
        "version": pkg["version"],
        "automation_mode": pkg["automation_mode"],
        "duration_hint_seconds": int(pkg["duration_seconds"]),
        "override_policy": "per_source_manual_exit",
        "manual_override_track_ids": [],
        "phrases": phrases,
        "cues": cues,
    }


def main() -> None:
    out = build()
    sys.path.insert(0, str(ROOT / "server"))
    from app.schemas.content import SceneTimelineOut

    SceneTimelineOut.model_validate(out)
    text = json.dumps(out, ensure_ascii=False, indent=2) + "\n"
    SERVER_OUT.write_text(text, encoding="utf-8")
    IOS_OUT.write_text(text, encoding="utf-8")
    action_counts: dict[str, int] = {}
    for cue in out["cues"]:
        for action in cue["actions"]:
            action_counts[action["type"]] = action_counts.get(action["type"], 0) + 1
    print(f"wrote {SERVER_OUT} and {IOS_OUT}")
    print(
        f"version={out['version']} phrases={len(out['phrases'])} "
        f"cues={len(out['cues'])} actions={action_counts}"
    )


if __name__ == "__main__":
    main()
