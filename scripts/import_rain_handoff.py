"""Convert sc_rain_v1's authored v11 timeline to runtime revision 12."""

import argparse
import hashlib
import json
import uuid
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCENE = uuid.UUID("a1111111-1111-4111-8111-111111111102")
EXPECTED_TIMELINE_SHA256 = (
    "b11c88c62670154312a69ca63f67bbd825c58a77906798102d9da8788d88749e"
)
TRACKS = {
    "rain_soft": "e5555555-5555-4555-8555-555555555510",
    "rain_parasol": "e5555555-5555-4555-8555-555555555501",
    "rain_bamboo_leaf": "e5555555-5555-4555-8555-555555555512",
    "wind_gust": "e5555555-5555-4555-8555-555555555502",
}


def convert(package):
    path = package / "scene/timeline.json"
    timeline_bytes = path.read_bytes()
    timeline_digest = hashlib.sha256(timeline_bytes).hexdigest()
    if timeline_digest != EXPECTED_TIMELINE_SHA256:
        raise ValueError(
            "Unexpected scene/timeline.json SHA-256: "
            f"expected={EXPECTED_TIMELINE_SHA256}, received={timeline_digest}"
        )
    source = json.loads(timeline_bytes.decode("utf-8-sig"))
    if source.get("scene_id") != "sc_rain" or source.get("version") != 11:
        raise ValueError("Expected sc_rain timeline version 11")
    tracks = source.get("tracks")
    if not isinstance(tracks, list):
        raise TypeError("Expected timeline tracks to be a list")
    resource_keys = [track.get("resource_key") for track in tracks]
    if len(resource_keys) != len(TRACKS) or set(resource_keys) != set(TRACKS):
        raise ValueError(
            f"Expected exactly these resource keys: {sorted(TRACKS)}; "
            f"received: {sorted(str(key) for key in resource_keys)}"
        )
    track_ids = [track.get("track_id") for track in tracks]
    if None in track_ids or len(set(track_ids)) != len(track_ids):
        raise ValueError("Expected each source track to have a unique track_id")
    mapping = {track["track_id"]: TRACKS[track["resource_key"]] for track in tracks}
    cues = defaultdict(list)
    hashes = {}
    for track in tracks:
        key = track["resource_key"]
        delivered = package / "audio/master" / track["master_file"]
        bundled = ROOT / "DreamWeaver/Resources/Audio" / f"{key}.wav"
        digest = hashlib.sha256(delivered.read_bytes()).hexdigest()
        bundled_digest = hashlib.sha256(bundled.read_bytes()).hexdigest()
        if digest != bundled_digest:
            raise ValueError(
                f"SHA-256 mismatch for {key}: delivered={digest}, bundled={bundled_digest}"
            )
        hashes[key] = digest
        for frame in track["position_keyframes"]:
            cues[frame["at_seconds"]].append(
                {
                    "type": "set_position",
                    "track_id": TRACKS[key],
                    "angle": frame["angle"],
                    "radius": frame["radius"],
                }
            )
        if not track["loop"]:
            for event in track["playback_events"]:
                end = event["start_seconds"] + event["playback_duration_seconds"]
                cues[end].extend(
                    {"type": kind, "track_id": TRACKS[key]}
                    for kind in ("pause", "disable")
                )
    for cue in source["cues"]:
        for original in cue["actions"]:
            action = {**original, "track_id": mapping[original["track_id"]]}
            if action["type"] == "set_volume":
                action["type"] = "set_envelope"
                action["envelope"] = action.pop("volume")
            cues[cue["at_seconds"]].append(action)
    return {
        "scene_id": str(SCENE),
        "version": 12,
        "automation_mode": "official_auto",
        "duration_hint_seconds": int(source["duration_seconds"]),
        "override_policy": "per_source_manual_exit",
        "manual_override_track_ids": [],
        "phrases": [],
        "_handoff": {
            "package": "sc_rain_v1",
            "source_version": 11,
            "release_ready": False,
            "timeline_sha256": timeline_digest,
            "audio_sha256": hashes,
        },
        "cues": [
            {
                "id": str(uuid.uuid5(SCENE, f"handoff-v11:{at:g}")),
                "at_seconds": at,
                "actions": actions,
            }
            for at, actions in sorted(cues.items())
        ],
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", type=Path)
    payload = convert(parser.parse_args().package)
    # One cue per line keeps generated fixtures reviewable; no authored cue is dropped.
    header = {key: value for key, value in payload.items() if key != "cues"}
    text = json.dumps(header, ensure_ascii=False, indent=2)[:-2] + ',\n  "cues": [\n'
    text += ',\n'.join('    ' + json.dumps(cue) for cue in payload["cues"]) + '\n  ]\n}\n'
    for folder in ("server/app/fixtures", "DreamWeaver/Resources/Mock"):
        (ROOT / folder / "rain_eaves_timeline_v12.json").write_text(text, encoding="utf-8")
    print(f"Generated runtime v12: {len(payload['cues'])} cues")
