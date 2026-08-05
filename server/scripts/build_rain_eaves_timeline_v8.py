"""Map sc_rain package timeline v8 → timeline-contract fixture (DemoIDs)."""

from __future__ import annotations

import json
import sys
import uuid
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "docs/scenes/sc_rain/packages/sc_rain_v1/scene/timeline.json"
SERVER_OUT = ROOT / "server/app/fixtures/rain_eaves_timeline_v8.json"
IOS_OUT = ROOT / "DreamWeaver/Resources/Mock/rain_eaves_timeline_v8.json"

SCENE_ID = "a1111111-1111-4111-8111-111111111102"
TRACK_MAP = {
    "675d3d70-7f0b-49a1-b754-ed38d163ba41": "e5555555-5555-4555-8555-555555555510",
    "819f884b-81b5-4a47-8d0d-d2fc2ee55348": "e5555555-5555-4555-8555-555555555501",
    "323ebc52-41ed-43b6-a097-77f55204d09e": "e5555555-5555-4555-8555-555555555512",
    "2cc9eff1-4520-46e1-a9d2-826b3299b7b5": "e5555555-5555-4555-8555-555555555502",
}
WIND_ID = TRACK_MAP["2cc9eff1-4520-46e1-a9d2-826b3299b7b5"]
FIXED_CUE_IDS = {(0.0, "enter-soft"): "f6666666-6666-4666-8666-666666666630"}


def remap_track(tid: str) -> str:
    return TRACK_MAP[tid]


def cue_id_for(at: float, tag: str) -> str:
    key = (float(at), tag)
    if key in FIXED_CUE_IDS:
        return FIXED_CUE_IDS[key]
    return str(uuid.uuid5(uuid.UUID(SCENE_ID), f"rain-v8-{at:.6f}-{tag}"))


def sort_key(action: dict) -> tuple:
    """Loop enter: vol0 → play → fade-in. Oneshot: set volume (fade 0) before play_oneshot."""
    order = {
        "set_position": 0,
        "enable": 1,
        "play": 3,
        "play_oneshot": 3,
        "pause": 4,
        "disable": 5,
    }
    t = action.get("type", "")
    if t == "set_volume":
        vol = float(action.get("volume") or 0)
        fade = int(action.get("fade_ms") or 0)
        if vol == 0:
            return (1.5, 0.0)
        # Instant level (oneshot / pre-roll) before play*; long fades after play.
        if fade <= 0:
            return (2.5, vol)
        return (3.5, vol)
    return (order.get(t, 9), 0.0)


def normalize_at(at: float) -> float | int:
    if float(at).is_integer():
        return int(at)
    return float(at)


def build() -> dict:
    pkg = json.loads(PKG.read_text(encoding="utf-8"))
    buckets: dict[float, list[dict]] = defaultdict(list)
    bucket_tags: dict[float, str] = {}

    for cue in pkg["cues"]:
        at = float(cue["at_seconds"])
        tag = cue.get("id", "cue")
        bucket_tags.setdefault(at, tag)
        for raw in cue["actions"]:
            action = dict(raw)
            if "track_id" in action:
                action["track_id"] = remap_track(action["track_id"])
            buckets[at].append(action)

    for track in pkg["tracks"]:
        eng_id = remap_track(track["track_id"])
        for kf in track.get("position_keyframes", []):
            at = float(kf["at_seconds"])
            action = {
                "type": "set_position",
                "track_id": eng_id,
                "angle": kf["angle"],
                "radius": kf["radius"],
            }
            existing = buckets[at]
            if any(
                a.get("type") == "set_position"
                and a.get("track_id") == eng_id
                and a.get("angle") == action["angle"]
                and a.get("radius") == action["radius"]
                for a in existing
            ):
                continue
            existing.append(action)
            bucket_tags.setdefault(at, f"pos-{track['code']}")

    for at, actions in buckets.items():
        pos_by_track: dict[str, dict] = {}
        others: list[dict] = []
        for action in actions:
            if action.get("type") == "set_position":
                pos_by_track[action["track_id"]] = action
            else:
                others.append(action)
        buckets[at] = sorted(list(pos_by_track.values()) + others, key=sort_key)

    cues_out = []
    for at in sorted(buckets.keys()):
        tag = "enter-soft" if at == 0.0 else bucket_tags.get(at, "auto")
        cues_out.append(
            {
                "id": cue_id_for(at, tag),
                "at_seconds": normalize_at(at),
                "actions": buckets[at],
            }
        )

    return {
        "scene_id": SCENE_ID,
        "version": 8,
        "automation_mode": "official_auto",
        "duration_hint_seconds": int(pkg.get("duration_seconds", 620)),
        "override_policy": "per_source_manual_exit",
        "manual_override_track_ids": [],
        "phrases": [],
        "cues": cues_out,
    }


def main() -> None:
    out = build()
    try:
        sys.path.insert(0, str(ROOT / "server"))
        from app.schemas.content import SceneTimelineOut

        SceneTimelineOut.model_validate(out)
        print("schema OK")
    except Exception as exc:  # noqa: BLE001 — optional when deps missing
        print(f"schema skip: {exc}")
    text = json.dumps(out, ensure_ascii=False, indent=2) + "\n"
    SERVER_OUT.write_text(text, encoding="utf-8")
    IOS_OUT.write_text(text, encoding="utf-8")
    oneshots = sum(1 for c in out["cues"] for a in c["actions"] if a["type"] == "play_oneshot")
    pos_cues = sum(1 for c in out["cues"] if any(a["type"] == "set_position" for a in c["actions"]))
    print(f"wrote {SERVER_OUT} and {IOS_OUT}")
    print(f"cues={len(out['cues'])} play_oneshot={oneshots} set_position_cues={pos_cues}")
    for cue in out["cues"]:
        wind = [a["type"] for a in cue["actions"] if a.get("track_id") == WIND_ID]
        if wind:
            print(f"  t={cue['at_seconds']}: {wind}")


if __name__ == "__main__":
    main()
