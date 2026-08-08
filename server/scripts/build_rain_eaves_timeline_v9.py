"""Compile sc_rain orchestration v9 CSVs into the shared timeline fixture."""

from __future__ import annotations

import csv
import json
import math
import sys
import uuid
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ORCHESTRATION = (
    ROOT / "docs/scenes/sc_rain/packages/sc_rain_v1/orchestration_v9"
)
SERVER_OUT = ROOT / "server/app/fixtures/rain_eaves_timeline_v9.json"
IOS_OUT = ROOT / "DreamWeaver/Resources/Mock/rain_eaves_timeline_v9.json"

SCENE_ID = "a1111111-1111-4111-8111-111111111102"
RUNTIME_VERSION = 11
GROUP_TRACK_IDS = {
    "G_A01": "e5555555-5555-4555-8555-555555555510",
    "G_A02": "e5555555-5555-4555-8555-555555555501",
    "G_A03": "e5555555-5555-4555-8555-555555555512",
    "G_A04": "e5555555-5555-4555-8555-555555555502",
}


def _rows(name: str) -> list[dict[str, str]]:
    with (ORCHESTRATION / name).open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def _number(value: float) -> float | int:
    return int(value) if value.is_integer() else round(value, 6)


def _cue_id(at: float) -> str:
    return str(uuid.uuid5(uuid.UUID(SCENE_ID), f"rain-v9-{at:.6f}"))


def _sort_key(action: dict) -> tuple[float, float]:
    action_type = action.get("type", "")
    if action_type == "set_position":
        return (0, 0)
    if action_type == "enable":
        return (1, 0)
    if action_type == "set_envelope":
        envelope = float(action.get("envelope") or 0)
        fade_ms = int(action.get("fade_ms") or 0)
        if envelope == 0 and fade_ms == 0:
            return (2, 0)
        if envelope > 0 and fade_ms == 0:
            return (3, envelope)
        if envelope == 0:
            return (5, 0)
        return (4, envelope)
    if action_type in {"play", "play_oneshot"}:
        return (3.5, 0)
    if action_type == "pause":
        return (6, 0)
    if action_type == "disable":
        return (7, 0)
    return (9, 0)


def build() -> dict:
    groups = _rows("source_groups.csv")
    clips = _rows("clips.csv")
    frames = _rows("position_keyframes.csv")
    known_groups = {row["group_code"] for row in groups}
    if known_groups != set(GROUP_TRACK_IDS):
        raise ValueError(f"unexpected source groups: {sorted(known_groups)}")

    buckets: dict[float, list[dict]] = defaultdict(list)
    for frame in frames:
        group_code = frame["group_code"]
        if group_code not in known_groups:
            raise ValueError(f"unknown keyframe group: {group_code}")
        radius = float(frame["radius"])
        angle_degrees = float(frame["angle_deg"])
        if not 0 <= radius <= 1 or not -180 <= angle_degrees <= 180:
            raise ValueError(f"invalid spatial keyframe: {frame}")
        buckets[float(frame["t_seconds"])].append(
            {
                "type": "set_position",
                "track_id": GROUP_TRACK_IDS[group_code],
                "angle": round(math.radians(angle_degrees), 6),
                "radius": radius,
            }
        )

    for clip in clips:
        group_code = clip["group_code"]
        if group_code not in known_groups:
            raise ValueError(f"unknown clip group: {group_code}")
        track_id = GROUP_TRACK_IDS[group_code]
        start = float(clip["start_seconds"])
        end = float(clip["end_seconds"])
        if not 0 <= start < end <= 620:
            raise ValueError(f"invalid clip window: {clip}")
        mode = clip["playback_mode"]
        fade_in_ms = int(clip["fade_in_ms"])
        fade_out_ms = int(clip["fade_out_ms"])
        crossfade_ms = int(clip["crossfade_ms"])
        if fade_in_ms + fade_out_ms > round((end - start) * 1000):
            raise ValueError(f"clip fades exceed window: {clip['clip_code']}")
        if mode == "oneshot" and crossfade_ms != 0:
            raise ValueError(f"oneshot crossfade must be zero: {clip['clip_code']}")
        if mode != "oneshot" and crossfade_ms <= 0:
            raise ValueError(f"loop crossfade is required: {clip['clip_code']}")

        buckets[start].append({"type": "enable", "track_id": track_id})
        buckets[start].append(
            {
                "type": "set_envelope",
                "track_id": track_id,
                "fade_ms": 0,
                "envelope": 0 if fade_in_ms else 1,
            }
        )
        buckets[start].append(
            {
                "type": "play_oneshot" if mode == "oneshot" else "play",
                "track_id": track_id,
            }
        )
        if fade_in_ms:
            buckets[start].append(
                {
                    "type": "set_envelope",
                    "track_id": track_id,
                    "fade_ms": fade_in_ms,
                    "envelope": 1,
                }
            )
        if fade_out_ms:
            fade_start = end - fade_out_ms / 1000
            buckets[fade_start].append(
                {
                    "type": "set_envelope",
                    "track_id": track_id,
                    "fade_ms": fade_out_ms,
                    "envelope": 0,
                }
            )
        buckets[end].append({"type": "pause", "track_id": track_id})
        buckets[end].append({"type": "disable", "track_id": track_id})

    cues = [
        {
            "id": _cue_id(at),
            "at_seconds": _number(at),
            "actions": sorted(actions, key=_sort_key),
        }
        for at, actions in sorted(buckets.items())
    ]
    return {
        "scene_id": SCENE_ID,
        "version": RUNTIME_VERSION,
        "automation_mode": "official_auto",
        "duration_hint_seconds": 620,
        "override_policy": "per_source_manual_exit",
        "manual_override_track_ids": [],
        "phrases": [],
        "cues": cues,
    }


def main() -> None:
    output = build()
    sys.path.insert(0, str(ROOT / "server"))
    from app.schemas.content import SceneTimelineOut

    SceneTimelineOut.model_validate(output)
    text = json.dumps(output, ensure_ascii=False, indent=2) + "\n"
    SERVER_OUT.write_text(text, encoding="utf-8")
    IOS_OUT.write_text(text, encoding="utf-8")
    actions = [action for cue in output["cues"] for action in cue["actions"]]
    print(f"wrote {SERVER_OUT} and {IOS_OUT}")
    print(
        f"cues={len(output['cues'])} actions={len(actions)} "
        f"positions={sum(action['type'] == 'set_position' for action in actions)} "
        f"oneshots={sum(action['type'] == 'play_oneshot' for action in actions)}"
    )


if __name__ == "__main__":
    main()
