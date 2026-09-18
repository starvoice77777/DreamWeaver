"""Bind reviewed fireplace or mist recipes to imported AAC resources."""

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
MIST_EXPECTED_SOURCE_HASHES = {
    "scene/timeline.json": (
        "b564f2e593b50cb71a8b95b4f9175c22d8d18c80cce9d38220445a24eef727b0"
    ),
    "scene/scene_manifest.json": (
        "99aec0780d154dd7d5b36333f154ca2f872a92336f9db487788193699c56319a"
    ),
    "scene/tracks.csv": (
        "acbe2be26849e2e71f4565d8e989f0cb115ea5b27fd3fd61cf2dd1b97dd156c9"
    ),
    "scene/source_map.csv": (
        "c7ab25117dd413c5f87f888063efa783a862c48badac48e955db87b1d56728c6"
    ),
    "qc/asset_qc.csv": (
        "274e82024a23e5820db3a6888c7f77f4eefe61020528bc41e7922b7f757a6c92"
    ),
    "licenses/license_manifest.csv": (
        "d5a0c2216e911ce9dad905fc3687143f5d4861d7f1e154043fe7bfe8ece9778d"
    ),
}
PRESETS = {
    "sc_fire_v01": {
        "scene_id": SCENE_ID,
        "cue_prefix": "fire",
        "subtitle": "炉火环境与偶发木柴轻响。",
        "tags": ["炉火", "静夜"],
        "output": OUTPUT,
        "source_hashes": EXPECTED_SOURCE_HASHES,
    },
    "sc_mist_v01": {
        "scene_id": uuid.UUID("a1111111-1111-4111-8111-111111111104"),
        "cue_prefix": "mist",
        "subtitle": "雾海缓潮，水声慢慢移过岸边。",
        "tags": ["雾海", "缓潮"],
        "output": OUTPUT.with_name("handoff_mist_v4.json"),
        "source_hashes": MIST_EXPECTED_SOURCE_HASHES,
    },
}


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rows(package, relative):
    with (package / relative).open(encoding="utf-8-sig", newline="") as stream:
        return {row["resource_key"]: row for row in csv.DictReader(stream)}


def validated_source_hashes(package, expected_hashes=EXPECTED_SOURCE_HASHES):
    hashes = {}
    for relative, expected in expected_hashes.items():
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


def output_for_scene(scene_id):
    for preset in PRESETS.values():
        if str(preset["scene_id"]) == scene_id:
            return preset["output"]
    raise ValueError(f"Unsupported runtime scene ID: {scene_id}")


def convert(package):
    timeline_path = package / "scene/timeline.json"
    if not timeline_path.is_file():
        raise ValueError("Missing reviewed source file: scene/timeline.json")
    source = read_json(timeline_path)
    preset = PRESETS.get(source.get("scene_id"))
    if preset is None or source.get("version") != 4:
        raise ValueError("Expected a supported review timeline v4")
    source_hashes = validated_source_hashes(package, preset["source_hashes"])
    manifest = read_json(package / "scene/scene_manifest.json")
    if (
        manifest.get("scene_id") != source["scene_id"]
        or manifest.get("release_ready") is not False
        or manifest.get("timeline_version") != source["version"]
    ):
        raise ValueError("Expected matching review manifest")
    scene_id = preset["scene_id"]
    tracks = rows(package, "scene/tracks.csv")
    mappings = rows(package, "scene/source_map.csv")
    qc = rows(package, "qc/asset_qc.csv")
    licenses = rows(package, "licenses/license_manifest.csv")
    catalog = read_json(AUDIO / "handoff_audio_catalog.json")["entries"]
    cues, sources, bindings, crossfades = defaultdict(list), [], [], {}
    tracks_by_id = {track["track_id"]: track for track in source["tracks"]}
    notes = []
    for track in source["tracks"]:
        key, track_id = track["resource_key"], track["track_id"]
        sha = digest(package / "audio/master" / track["master_file"])
        matches = [
            e
            for e in catalog
            if key in e["sceneResourceKeys"] and e["sourceSHA256"] == sha
        ]
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
                        a["type"] == "enable" and a["track_id"] == track_id
                        for a in c["actions"]
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
                "assetStatus": qc[key].get("status", qc[key].get("asset_status")),
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
            if action["type"] == "play_oneshot":
                track = tracks_by_id[action["track_id"]]
                has_event = any(
                    event["start_seconds"] == cue["at_seconds"]
                    for event in track.get("playback_events", [])
                )
                if not has_event:
                    end = min(
                        cue["at_seconds"] + track["asset_duration_seconds"],
                        source["duration_seconds"],
                    )
                    cues[end].append({"type": "pause", "track_id": action["track_id"]})
                    notes.append(
                        f"{track['resource_key']} at {cue['at_seconds']}s: "
                        "cue retained; missing playback_event end derived from asset duration"
                    )
    timeline = {
        "scene_id": str(scene_id),
        "version": 4,
        "automation_mode": "official_auto",
        "duration_hint_seconds": int(source["duration_seconds"]),
        "override_policy": "per_source_manual_exit",
        "manual_override_track_ids": [],
        "phrases": [],
        "cues": [
            {
                "id": str(
                    uuid.uuid5(scene_id, f"handoff-{preset['cue_prefix']}-v4:{at:g}")
                ),
                "at_seconds": at,
                "actions": actions,
            }
            for at, actions in sorted(cues.items())
        ],
    }
    return {
        "sceneID": str(scene_id),
        "name": manifest["scene_name"],
        "subtitle": preset["subtitle"],
        "tags": preset["tags"],
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
            **({"notes": notes} if notes else {}),
        },
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", type=Path)
    payload = convert(parser.parse_args().package)
    output = output_for_scene(payload["sceneID"])
    # Keep each generated source and cue together for review.
    parts = []
    for key, value in payload.items():
        if key == "timeline":
            rendered = json.dumps({k: v for k, v in value.items() if k != "cues"})[:-1]
            rendered += (
                ', "cues": [\n'
                + ",\n".join(json.dumps(c) for c in value["cues"])
                + "\n]}"
            )
        elif isinstance(value, list):
            rendered = (
                "[\n"
                + ",\n".join(json.dumps(v, ensure_ascii=False) for v in value)
                + "\n]"
            )
        else:
            rendered = json.dumps(value, ensure_ascii=False)
        parts.append(f'  "{key}": {rendered}')
    output.write_text("{\n" + ",\n".join(parts) + "\n}\n", encoding="utf-8")
    (ROOT / "server/app/fixtures" / output.name).write_bytes(output.read_bytes())
    print(f"Generated {output.name}: {len(payload['sources'])} sources")
