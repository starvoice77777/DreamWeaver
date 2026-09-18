"""Import v1.2 source-library audio for Debug review; never modify delivery files."""

import argparse
import csv
import hashlib
import json
import math
import re
import subprocess
import tempfile
import wave
from pathlib import Path

from imageio_ffmpeg import get_ffmpeg_exe

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "DreamWeaver/Resources/Audio"
NAMES = dict(line.split("=", 1) for line in """
air_winter_far=冬夜远处空气
air_winter_far_loop=冬夜空气循环
brown_noise_soft=柔和棕噪声
fire_soft_01=柔和炉火一
fire_soft_02=柔和炉火二
ocean_bed_soft=海洋底层
pink_noise_soft=柔和粉噪声
rain_far_soft=远处细雨
room_earcare_quiet=采耳房间底噪
room_earcare_quiet_loop=采耳房间底噪循环
room_fan_quiet_01=安静风扇一
room_fan_quiet_02=安静风扇二
room_quiet=安静房间
room_study_quiet=安静书房
room_study_quiet_loop=安静书房循环
sea_wind_soft=柔和海风
stream_far_soft=远处溪流
bird_call_far_01=远处鸟鸣一
bird_call_far_02=远处鸟鸣二
bird_call_far_03=远处鸟鸣三
boat_water_lap=水拍船身
insects_night_far=远处夜虫
paper_texture_loop=纸张纹理循环
paper_texture_soft=柔和纸张纹理
rain_bamboo_soft=竹叶细雨
rain_parasol_near=近处檐下雨
shore_water_soft=柔和岸边水声
snow_steps_soft=轻柔雪地脚步
train_distant_murmur=远处列车低鸣
boat_creak_soft=船木轻响
cloth_soft_a=柔软布料一
cloth_soft_b=柔软布料二
cookie_chew_optional=饼干咀嚼
ear_cotton_swab_long=棉棒轻拭
ear_goose_feather=鹅毛轻扫
ear_mic_scrape_optional=近耳刮擦
ear_oral_optional=近耳口腔声
ear_pick_soft=轻柔耳勺
ear_soft_brush=软刷轻拂
ear_sponge_press=海绵轻压
ear_tape_stick_optional=胶带轻粘
ear_threaded_wire_optional=螺纹棒摩擦
ear_tinfoil_optional=锡纸轻揉
glass_water_soft=玻璃杯水声
honeycomb_squeeze_soft=蜂窝轻挤
page_turn_slow_a=缓慢翻页一
page_turn_slow_b=缓慢翻页二
pencil_write_soft_a=铅笔轻写一
pencil_write_soft_b=铅笔轻写二
plastic_foam_soft=泡沫轻揉
seagull_far=远处海鸥
spring_metal_optional=金属弹簧
water_sip_soft=轻轻喝水
wind_gust_far=远处阵风
wood_crackle_01=木柴轻响一
wood_crackle_02=木柴轻响二
wood_crackle_03=木柴轻响三
""".strip().splitlines())


def sha256(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def checked_rows(root):
    root = root.resolve()
    with (root / "audio_asset_index.csv").open(encoding="utf-8-sig") as stream:
        rows = list(csv.DictReader(stream))
    for row in rows:
        path = (root / row["relative_path"]).resolve()
        if not path.is_relative_to(root) or not path.is_file():
            raise ValueError(f"Invalid source path: {row['relative_path']}")
        if path.stat().st_size != int(row["bytes"]) or sha256(path) != row["sha256"].lower():
            raise ValueError(f"Hash/size mismatch: {row['relative_path']}")
    sources = [row for row in rows if row["asset_scope"] == "source_library"]
    if len(sources) != 57 or {Path(row["relative_path"]).stem for row in sources} != NAMES.keys():
        raise ValueError("Expected the exact v1.2 source library (57 named files)")
    return rows, sources


def ffmpeg(*args):
    return subprocess.run(
        [get_ffmpeg_exe(), "-hide_banner", "-nostdin", "-nostats", *map(str, args)],
        capture_output=True, check=True,
    )


def measure(path):
    result = ffmpeg("-i", path, "-af", "loudnorm=I=-24:TP=-3:LRA=7:print_format=json",
                    "-f", "null", "-")
    values = json.loads(re.findall(rb'\{\s*"input_i".*?\}', result.stderr, re.S)[-1])
    loudness, peak = float(values["input_i"]), float(values["input_tp"])
    if not all(map(math.isfinite, (loudness, peak))):
        raise ValueError(f"Silent or invalid audio: {path}")
    return {"integratedLoudnessDB": loudness, "truePeakDB": peak}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("handoff", type=Path)
    args = parser.parse_args()
    rows, sources = checked_rows(args.handoff)
    profile_path = AUDIO / "audio_mastering_profile.json"
    profile = json.loads(profile_path.read_text(encoding="utf-8"))
    existing = {sha256(p): p for p in sorted(AUDIO.iterdir())
                if p.suffix in {".wav", ".m4a"} and not p.name.startswith("handoff_")}
    entries = []
    with tempfile.TemporaryDirectory(prefix="dw-handoff-") as scratch:
        stage = Path(scratch)
        for row in sources:
            source = args.handoff / row["relative_path"]
            stem = source.stem
            reused = row["sha256"] in existing
            output = existing.get(row["sha256"], stage / f"handoff_{stem}.m4a")
            with wave.open(str(source)) as wav:
                if (wav.getframerate(), wav.getnchannels()) != (48000, 2):
                    raise ValueError(f"Unexpected source format: {source}")
                duration = wav.getnframes() / wav.getframerate()
            if not reused:
                measured = measure(source)
                gain = min(-24 - measured["integratedLoudnessDB"], -3.5 - measured["truePeakDB"])
                for _ in range(3):
                    ffmpeg("-y", "-i", source, "-map_metadata", "-1", "-af", f"volume={gain}dB",
                           "-ar", "48000", "-ac", "2", "-c:a", "aac", "-b:a", "160k", output)
                    measured = measure(output)
                    if measured["truePeakDB"] <= -3:
                        break
                    # AAC can overshoot PCM peaks; attenuate and encode from the original.
                    gain -= measured["truePeakDB"] + 3.5
                if measured["truePeakDB"] > -3 or measured["integratedLoudnessDB"] > -23.5:
                    raise ValueError(f"Encoded output exceeds review limits: {stem}: {measured}")
                profile["measurements"][output.stem] = measured
            scene_keys = sorted({r["resource_key"] for r in rows
                                 if r["asset_scope"] == "scene_package"
                                 and r["sha256"] == row["sha256"]
                                 and r["package_variant"] == "master"})
            entries.append(dict(id=stem, name=NAMES[stem], resourceKey=output.stem,
                                file=output.name, durationSeconds=duration,
                                libraryCategory=source.parent.name, sceneResourceKeys=scene_keys,
                                sourcePath=row["relative_path"], sourceSHA256=row["sha256"],
                                outputSHA256=sha256(output), reusedExisting=reused,
                                assetStatus="qc_pending", licenseStatus="unreviewed"))
            print(f"{len(entries)}/57 {stem}: {'reused' if reused else 'encoded'}", flush=True)
        # Publish only after every indexed source and rendered output has passed checks.
        for entry in entries:
            if not entry["reusedExisting"]:
                (AUDIO / entry["file"]).write_bytes((stage / entry["file"]).read_bytes())
        # Keep authored profile formatting; append/replace only this importer's entries.
        original = profile_path.read_text(encoding="utf-8")
        original = re.sub(r'^    "handoff_[^\n]+\n', '', original, flags=re.M)
        addition = ''.join(f'    {json.dumps(k)}: {json.dumps(v)},\n'
                           for k, v in profile["measurements"].items() if k.startswith("handoff_"))
        updated = original.replace('"measurements": {\n', '"measurements": {\n' + addition)
        profile_path.write_text(updated, encoding="utf-8")
        header = '{\n  "version": 1, "handoff": "backend_handoff_v1.2", "releaseReady": false,\n'
        header += '  "usage": "debug_review_only", "entries": [\n'
        body = ',\n'.join('    ' + json.dumps(e, ensure_ascii=False) for e in entries)
        catalog_path = AUDIO / "handoff_audio_catalog.json"
        catalog_path.write_text(header + body + '\n  ]\n}\n', encoding="utf-8")


if __name__ == "__main__":
    main()
