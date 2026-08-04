import argparse
import csv
import json
import math
import subprocess
from pathlib import Path


def load_json(path):
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def probe_audio(path, ffprobe):
    cmd = [
        str(ffprobe), "-v", "error", "-select_streams", "a:0",
        "-show_entries", "stream=sample_rate,channels,codec_name",
        "-show_entries", "format=duration", "-of", "json", str(path),
    ]
    result = subprocess.run(cmd, check=True, capture_output=True, text=True, encoding="utf-8")
    data = json.loads(result.stdout)
    stream = data["streams"][0]
    return {
        "sample_rate": int(stream["sample_rate"]),
        "channels": int(stream["channels"]),
        "codec_name": stream["codec_name"],
        "duration": float(data["format"]["duration"]),
    }


def validate(package, ffprobe):
    errors = []
    warnings = []
    checked_audio = []
    manifest = load_json(package / "scene" / "scene_manifest.json")
    timeline = load_json(package / "scene" / "timeline.json")
    duration = float(timeline.get("duration_seconds", 0))

    if manifest.get("scene_id") != timeline.get("scene_id"):
        errors.append("scene_manifest 与 timeline 的 scene_id 不一致")
    if duration <= 0:
        errors.append("duration_seconds 必须大于0")

    with (package / "scene" / "tracks.csv").open("r", encoding="utf-8-sig", newline="") as f:
        track_rows = list(csv.DictReader(f))
    csv_ids = {row["track_id"] for row in track_rows}
    seen = set()

    for track in timeline.get("tracks", []):
        tid = track.get("track_id")
        if not tid:
            errors.append("存在缺少 track_id 的轨道")
            continue
        if tid in seen:
            errors.append(f"track_id 重复: {tid}")
        seen.add(tid)
        if tid not in csv_ids:
            errors.append(f"timeline track_id 未出现在 tracks.csv: {tid}")

        start = float(track.get("start_seconds", -1))
        playback = float(track.get("playback_duration_seconds", -1))
        asset_duration = float(track.get("asset_duration_seconds", -1))
        if start < 0 or playback <= 0 or asset_duration <= 0:
            errors.append(f"{tid}: 时间字段必须合法且大于0")
        if start + playback > duration + 0.001:
            errors.append(f"{tid}: 轨道结束时间超过场景总时长")

        keyframes = track.get("position_keyframes", [])
        if not keyframes:
            errors.append(f"{tid}: 缺少 position_keyframes")
        else:
            keyframe_times = [float(item.get("at_seconds", -1)) for item in keyframes]
            if abs(keyframe_times[0] - start) > 0.001:
                errors.append(f"{tid}: 第一条位置关键帧必须等于 start_seconds")
            if keyframe_times != sorted(keyframe_times) or len(keyframe_times) != len(set(keyframe_times)):
                errors.append(f"{tid}: 位置关键帧时间必须严格递增")
            for item in keyframes:
                at = float(item.get("at_seconds", -1))
                angle = float(item.get("angle", 99))
                radius = float(item.get("radius", -1))
                if at < start or at > start + playback + 0.001:
                    errors.append(f"{tid}: 位置关键帧超出本轨播放区间: {at}")
                if not -math.pi <= angle <= math.pi:
                    errors.append(f"{tid}: angle 超出 -π…π: {angle}")
                if not 0 <= radius <= 1:
                    errors.append(f"{tid}: radius 超出 0…1: {radius}")

        loop = track.get("loop")
        cross_required = track.get("requires_engine_crossfade")
        cross_ms = track.get("crossfade_ms")
        if not isinstance(loop, bool):
            errors.append(f"{tid}: loop 必须显式填写 Boolean")
        if loop is True and not isinstance(cross_required, bool):
            errors.append(f"{tid}: loop=true 时 requires_engine_crossfade 必填")
        if cross_required is True:
            if not isinstance(cross_ms, int) or not 300 <= cross_ms <= 2000:
                errors.append(f"{tid}: crossfade_ms 必须为300–2000的整数")
            elif cross_ms / 1000 >= asset_duration / 2:
                errors.append(f"{tid}: crossfade_ms 必须小于母带时长一半")

        master = package / "audio" / "master" / track.get("master_file", "")
        if not master.is_file():
            errors.append(f"{tid}: 推荐母带不存在: {master.name}")
            continue
        try:
            info = probe_audio(master, ffprobe)
        except Exception as exc:
            errors.append(f"{tid}: ffprobe 失败: {exc}")
            continue
        if info["sample_rate"] != 48000:
            errors.append(f"{tid}: 采样率不是48kHz")
        if info["channels"] != 2:
            warnings.append(f"{tid}: 当前不是双声道，请确认图层是否允许")
        if abs(info["duration"] - asset_duration) > 0.02:
            errors.append(f"{tid}: JSON时长{asset_duration}与文件时长{info['duration']:.6f}不一致")
        checked_audio.append({"track_id": tid, "file": master.name, **info})

    for row in track_rows:
        if row["track_id"] not in seen:
            warnings.append(f"tracks.csv 存在 timeline 未使用轨道: {row['track_id']}")

    return {
        "package": str(package),
        "scene_id": timeline.get("scene_id"),
        "passed": not errors,
        "errors": errors,
        "warnings": warnings,
        "checked_tracks": len(seen),
        "checked_audio": checked_audio,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("package")
    parser.add_argument("--ffprobe", required=True)
    parser.add_argument("--out")
    args = parser.parse_args()
    report = validate(Path(args.package), Path(args.ffprobe))
    text = json.dumps(report, ensure_ascii=False, indent=2)
    if args.out:
        Path(args.out).write_text(text + "\n", encoding="utf-8")
    print(text)
    raise SystemExit(0 if report["passed"] else 1)


if __name__ == "__main__":
    main()
