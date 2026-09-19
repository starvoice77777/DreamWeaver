"""Bind reviewed fireplace, mist, ear-care, or page recipes to AAC resources."""

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
EAR_EXPECTED_SOURCE_HASHES = {
    "scene/timeline.json": (
        "502a31026a87d13464ef7e11dbbb0fab1de936a3cc611a1cdee048729fecc90f"
    ),
    "scene/scene_manifest.json": (
        "bbe3c905d83722adfcb4abd63c76832345784a79a71bd2f4d1c0b1a6d10b8ac6"
    ),
    "scene/tracks.csv": (
        "41895c6a1ce49f662bea152a0194404c7cbc11f025c660cf10162fe2db6e61a9"
    ),
    "scene/source_map.csv": (
        "64a6863535029aa74dac4d3c68065fc20466afd3c74b520b101409d617bb0eed"
    ),
    "qc/asset_qc.csv": (
        "a6eb2da0cf8f67f6ea20b4aca545fd6e33d42bdd7aa199c3d687810fadb7c3d5"
    ),
    "licenses/license_manifest.csv": (
        "0ec9150436c77c60d4fb08495f1fd2fd66e5a87f9db0e45fcd5ca2f527419fe6"
    ),
}
PAGE_EXPECTED_SOURCE_HASHES = {
    "scene/timeline.json": (
        "1ed2fb71e9e4d909b7b7d44d0a7efbfb7b0735155120d3deee69a6137289513b"
    ),
    "scene/scene_manifest.json": (
        "3317ef14ec89d515a39ff3a1c52d4fc91a172012a1f16876a837b9c633f21907"
    ),
    "scene/tracks.csv": (
        "8fce60aa3d21a99ec37f0be589123211381d2e0e912a0dc3b62e43d119f9c7b1"
    ),
    "scene/source_map.csv": (
        "97b5bae540d54d27542c35f99c22e2b0730c9775cb05f7016fe6900078132e7a"
    ),
    "qc/asset_qc.csv": (
        "2a3af6ad78a0257dc777a7be873252075e40efccab0258c501ee0ab38c7e7456"
    ),
    "licenses/license_manifest.csv": (
        "f6d928b0c699d40ea56bdbe13e1922fde13736ae118e241705de44c89347cc5e"
    ),
}
EXPECTED_ASSET_INDEX_HASH = (
    "6f1907dab0df80c51b15ed0227ffaa6586b328333f966e1e5587823154c521c9"
)
EAR_SOURCE_MAP_SHA_EXCEPTIONS = {
    "ear_goose_feather_01": (
        "cb0e1b94b40bef362f14cb024e20bad8818f3694726d761d1be6a0c13f177b"
    )
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
    "sc_ear_v01": {
        "scene_id": uuid.UUID("a1111111-1111-4111-8111-111111111113"),
        "cue_prefix": "ear",
        "subtitle": "安静房间里，细微触感缓慢穿过左右耳侧。",
        "tags": ["采耳", "ASMR"],
        "output": OUTPUT.with_name("handoff_ear_v4.json"),
        "source_hashes": EAR_EXPECTED_SOURCE_HASHES,
        "asset_index_hash": EXPECTED_ASSET_INDEX_HASH,
        "source_map_sha_exceptions": EAR_SOURCE_MAP_SHA_EXCEPTIONS,
        "zero_first_oneshot_envelope": True,
    },
    "sc_page_v01": {
        "scene_id": uuid.UUID("a1111111-1111-4111-8111-111111111114"),
        "cue_prefix": "page",
        "subtitle": "冬夜书房里，翻页与轻写字声缓慢陪你入眠。",
        "tags": ["翻页", "书房", "ASMR"],
        "output": OUTPUT.with_name("handoff_page_v4.json"),
        "source_hashes": PAGE_EXPECTED_SOURCE_HASHES,
        "asset_index_hash": EXPECTED_ASSET_INDEX_HASH,
        "zero_first_oneshot_envelope": True,
    },
}


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def cue_time(value):
    """Canonicalize handoff timestamps before using them as cue dictionary keys."""
    return round(value, 6)


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


def validated_asset_index(package, expected_hash):
    path = package.parents[1] / "audio_asset_index.csv"
    if not path.is_file():
        raise ValueError("Missing reviewed source file: audio_asset_index.csv")
    received = digest(path)
    if received != expected_hash:
        raise ValueError(
            "Unexpected source package SHA-256 for audio_asset_index.csv: "
            f"expected={expected_hash}, received={received}"
        )
    with path.open(encoding="utf-8-sig", newline="") as stream:
        return received, list(csv.DictReader(stream))


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
    asset_index_hash = None
    asset_index = []
    if expected_index_hash := preset.get("asset_index_hash"):
        asset_index_hash, asset_index = validated_asset_index(
            package, expected_index_hash
        )
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
        mapping_sha = mappings[key]["sha256"].lower()
        mapping_exception = preset.get("source_map_sha_exceptions", {}).get(key)
        uses_mapping_exception = mapping_sha != sha
        indexed_hashes = {
            row["sha256"].lower()
            for row in asset_index
            if row["resource_key"] == key
        }
        if (
            len(matches) != 1
            or (
                uses_mapping_exception
                and (
                    mapping_sha != mapping_exception
                    or sha not in indexed_hashes
                )
            )
            or (not uses_mapping_exception and mapping_exception is not None)
        ):
            raise ValueError(f"Unverified master binding: {key}")
        if uses_mapping_exception:
            notes.append(
                f"scene/source_map.csv {key} contains a known "
                f"{len(mapping_sha)}-character SHA-256 typo; binding verified "
                "against the master file, audio_asset_index.csv, and the "
                "application audio catalog."
            )
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
            cues[cue_time(frame["at_seconds"])].append(
                {
                    "type": "set_position",
                    "track_id": track_id,
                    "angle": frame["angle"],
                    "radius": frame["radius"],
                }
            )
        for event in track.get("playback_events", []):
            end = cue_time(
                event["start_seconds"] + event["playback_duration_seconds"]
            )
            cues[end].append({"type": "pause", "track_id": track_id})
    seen_oneshot_tracks = set()
    for cue in source["cues"]:
        at_seconds = cue_time(cue["at_seconds"])
        first_oneshot_tracks = {
            action["track_id"]
            for action in cue["actions"]
            if action["type"] == "play_oneshot"
            and action["track_id"] not in seen_oneshot_tracks
        }
        initialized_oneshot_tracks = set()
        for original in cue["actions"]:
            action = original.copy()
            if action["type"] == "set_volume":
                action["type"] = "set_envelope"
                action["envelope"] = action.pop("volume")
            if (
                preset.get("zero_first_oneshot_envelope")
                and action["type"] == "set_envelope"
                and action["track_id"] in first_oneshot_tracks
                and action["track_id"] not in initialized_oneshot_tracks
                and action["envelope"] > 0
                and action.get("fade_ms", 0) > 0
            ):
                cues[at_seconds].append(
                    {
                        "type": "set_envelope",
                        "track_id": action["track_id"],
                        "fade_ms": 0,
                        "envelope": 0.0,
                    }
                )
                initialized_oneshot_tracks.add(action["track_id"])
            cues[at_seconds].append(action)
            if action["type"] == "play_oneshot":
                if (
                    preset.get("zero_first_oneshot_envelope")
                    and action["track_id"] in first_oneshot_tracks
                    and action["track_id"] not in initialized_oneshot_tracks
                ):
                    raise ValueError(
                        "First one-shot must define a positive envelope fade: "
                        f"{action['track_id']}"
                    )
                seen_oneshot_tracks.add(action["track_id"])
                track = tracks_by_id[action["track_id"]]
                has_event = any(
                    cue_time(event["start_seconds"]) == at_seconds
                    for event in track.get("playback_events", [])
                )
                if not has_event:
                    end = cue_time(
                        min(
                            at_seconds + track["asset_duration_seconds"],
                            source["duration_seconds"],
                        )
                    )
                    cues[end].append({"type": "pause", "track_id": action["track_id"]})
                    notes.append(
                        f"{track['resource_key']} at {at_seconds}s: "
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
            **(
                {"assetIndexSHA256": asset_index_hash}
                if asset_index_hash is not None
                else {}
            ),
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
