"""Bind the reviewed fireplace recipe to the already imported AAC resources."""

import argparse
import csv
import hashlib
import json
import uuid
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "DreamWeaver/Resources/Audio"
OUTPUT = ROOT / "DreamWeaver/Resources/Mock/handoff_fireplace_v4.json"
SCENE_ID = uuid.UUID("a1111111-1111-4111-8111-11111111110d")
EXPECTED_SOURCE_HASHES = {
    "scene/timeline.json": (
        "25eb3e4e569ec130b009106070e63920833c625f2281e0f770cec5706312c941"
    ),
    "scene/scene_manifest.json": (
        "0aea0833f245b6008c775e7cda5711a7014f024232e7f348c5b2282188d57012"
    ),
    "scene/tracks.csv": (
        "adf2a0a0bec3f192c657589f120f366f1f6dec589067cb006cc655bfd3f42e78"
    ),
    "scene/source_map.csv": (
        "40d99108dba6864e0cb9e9511c112d2f50dac2b12fc7053fb84a72614ee25f1a"
    ),
    "qc/asset_qc.csv": (
        "cbbfcb84f767682aab99d5803ec937df37b3aabd0e75dfd963e1a5dadc60ce61"
    ),
    "licenses/license_manifest.csv": (
        "e59e0a6e752c63afa02a012fc00e525fbfeccbbad9c3407d17a864e6ec9512dc"
    ),
}


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rows(package, relative):
    with (package / relative).open(encoding="utf-8-sig", newline="") as stream:
        return {row["resource_key"]: row for row in csv.DictReader(stream)}


def validated_source_hashes(package):
    hashes = {}
    for relative, expected in EXPECTED_SOURCE_HASHES.items():
        path = package / relative
        if not path.is_file():
            raise ValueError(f"Missing reviewed source file: {relative}")
        received = digest(path)
        if received != expected:
            raise ValueError(
                f"Unexpected source package SHA-256 for {relative}: "
                f"expected={expected}, received={received}"
            )
        hashes[relative] = received
    return hashes


def convert(package):
    source_hashes = validated_source_hashes(package)
    source = read_json(package / "scene/timeline.json")
    manifest = read_json(package / "scene/scene_manifest.json")
    if source["scene_id"] != "sc_fire_v01" or source["version"] != 4:
        raise ValueError("Expected sc_fire_v01 timeline v4")
    if manifest["release_ready"] or manifest["timeline_version"] != source["version"]:
        raise ValueError("Expected matching review manifest")
    tracks = rows(package, "scene/tracks.csv")
    mappings = rows(package, "scene/source_map.csv")
    qc = rows(package, "qc/asset_qc.csv")
    licenses = rows(package, "licenses/license_manifest.csv")
    catalog = read_json(AUDIO / "handoff_audio_catalog.json")["entries"]
    cues, sources, bindings, crossfades = defaultdict(list), [], [], {}
    for track in source["tracks"]:
        key, track_id = track["resource_key"], track["track_id"]
        sha = digest(package / "audio/master" / track["master_file"])
        matches = [e for e in catalog if key in e["sceneResourceKeys"] and e["sourceSHA256"] == sha]
        if len(matches) != 1 or mappings[key]["sha256"].lower() != sha:
            raise ValueError(f"Unverified master binding: {key}")
        entry = matches[0]
        if digest(AUDIO / entry["file"]) != entry["outputSHA256"]:
            raise ValueError(f"Changed encoded audio: {key}")
        if (
            tracks[key]["track_id"] != track_id
            or tracks[key]["master_file"] != track["master_file"]
        ):
            raise ValueError(f"Inconsistent track identity: {key}")
        frame = track["position_keyframes"][0]
        sources.append(
            {
                "id": track_id,
                "name": entry["name"],
                "symbolName": "flame.fill" if key.startswith("fire") else "waveform",
                "resourceName": entry["resourceKey"],
                "layer": track["layer"],
                "initialEnvelope": 1,
                "isEnabled": any(
                    c["at_seconds"] == 0
                    and any(
                        a["type"] == "enable" and a["track_id"] == track_id for a in c["actions"]
                    )
                    for c in source["cues"]
                ),
                "position": {"angle": frame["angle"], "radius": frame["radius"]},
            }
        )
        if track["loop"]:
            crossfades[entry["resourceKey"]] = track["crossfade_ms"]
        bindings.append(
            {
                "resourceKey": entry["resourceKey"],
                "sourceResourceKey": key,
                "sourceSHA256": sha,
                "outputSHA256": entry["outputSHA256"],
                "assetStatus": qc[key]["status"],
                "licenseStatus": licenses[key]["license_status"],
            }
        )
        for frame in track["position_keyframes"]:
            cues[frame["at_seconds"]].append(
                {
                    "type": "set_position",
                    "track_id": track_id,
                    "angle": frame["angle"],
                    "radius": frame["radius"],
                }
            )
        for event in track.get("playback_events", []):
            end = event["start_seconds"] + event["playback_duration_seconds"]
            cues[end].append({"type": "pause", "track_id": track_id})
    for cue in source["cues"]:
        for original in cue["actions"]:
            action = original.copy()
            if action["type"] == "set_volume":
                action["type"] = "set_envelope"
                action["envelope"] = action.pop("volume")
            cues[cue["at_seconds"]].append(action)
    timeline = {
        "scene_id": str(SCENE_ID),
        "version": 4,
        "automation_mode": "official_auto",
        "duration_hint_seconds": int(source["duration_seconds"]),
        "override_policy": "per_source_manual_exit",
        "manual_override_track_ids": [],
        "phrases": [],
        "cues": [
            {
                "id": str(uuid.uuid5(SCENE_ID, f"handoff-fire-v4:{at:g}")),
                "at_seconds": at,
                "actions": actions,
            }
            for at, actions in sorted(cues.items())
        ],
    }
    return {
        "sceneID": str(SCENE_ID),
        "name": manifest["scene_name"],
        "subtitle": "炉火环境与偶发木柴轻响。",
        "tags": ["炉火", "静夜"],
        "releaseReady": False,
        "usage": "debug_review_only",
        "sources": sources,
        "loopCrossfades": crossfades,
        "timeline": timeline,
        "provenance": {
            "package": package.name,
            "sourceHashes": source_hashes,
            "releaseBlockers": manifest["release_blockers"],
            "bindings": bindings,
        },
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", type=Path)
    payload = convert(parser.parse_args().package)
    # Keep each generated source and cue together for review.
    parts = []
    for key, value in payload.items():
        if key == "timeline":
            rendered = json.dumps({k: v for k, v in value.items() if k != "cues"})[:-1]
            rendered += ', "cues": [\n' + ",\n".join(json.dumps(c) for c in value["cues"]) + "\n]}"
        elif isinstance(value, list):
            rendered = "[\n" + ",\n".join(json.dumps(v, ensure_ascii=False) for v in value) + "\n]"
        else:
            rendered = json.dumps(value, ensure_ascii=False)
        parts.append(f'  "{key}": {rendered}')
    OUTPUT.write_text("{\n" + ",\n".join(parts) + "\n}\n", encoding="utf-8")
    (ROOT / "server/app/fixtures" / OUTPUT.name).write_bytes(OUTPUT.read_bytes())
    print(f"Generated {OUTPUT.name}: {len(payload['sources'])} sources")
