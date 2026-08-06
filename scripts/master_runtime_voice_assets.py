"""Loudness-master bundled hair-care voice phrases without touching source packages.

Requires ``imageio-ffmpeg``. The script renders every target to a temporary file,
validates all outputs, and only then atomically replaces the App Bundle copies.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

from imageio_ffmpeg import get_ffmpeg_exe

TARGET_I = -18.0
TARGET_TP = -3.0
TARGET_LRA = 7.0
LOUDNORM_JSON = re.compile(r"\{\s*\"input_i\".*?\}", re.DOTALL)


def run_loudnorm(path: Path) -> dict[str, str]:
    command = [
        get_ffmpeg_exe(),
        "-hide_banner",
        "-nostats",
        "-i",
        str(path),
        "-af",
        f"loudnorm=I={TARGET_I}:TP={TARGET_TP}:LRA={TARGET_LRA}:print_format=json",
        "-f",
        "null",
        "NUL" if os.name == "nt" else "/dev/null",
    ]
    result = subprocess.run(command, capture_output=True, text=True, check=True)
    matches = LOUDNORM_JSON.findall(result.stderr)
    if not matches:
        raise RuntimeError(f"Unable to parse loudnorm output for {path.name}")
    return json.loads(matches[-1])


def render_master(source: Path, target: Path, measured: dict[str, str]) -> None:
    filter_value = (
        f"loudnorm=I={TARGET_I}:TP={TARGET_TP}:LRA={TARGET_LRA}"
        f":measured_I={measured['input_i']}"
        f":measured_TP={measured['input_tp']}"
        f":measured_LRA={measured['input_lra']}"
        f":measured_thresh={measured['input_thresh']}"
        f":offset={measured['target_offset']}"
        ":linear=false:print_format=json"
    )
    command = [
        get_ffmpeg_exe(),
        "-hide_banner",
        "-nostats",
        "-y",
        "-i",
        str(source),
        "-af",
        filter_value,
        "-ar",
        "48000",
        "-ac",
        "2",
        "-c:a",
        "pcm_s16le",
        str(target),
    ]
    subprocess.run(command, capture_output=True, text=True, check=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("audio_root", type=Path)
    parser.add_argument(
        "--check-only",
        action="store_true",
        help="Analyze the current bundle files without rewriting them.",
    )
    args = parser.parse_args()
    root = args.audio_root.resolve()
    if not root.is_dir():
        raise SystemExit(f"Audio root does not exist: {root}")

    sources = sorted(root.glob("voice_phrase_[0-9][0-9].wav"))
    if len(sources) != 20:
        raise SystemExit(f"Expected 20 voice phrases, found {len(sources)} in {root}")

    pending: list[tuple[Path, Path]] = []
    report: list[dict[str, float | str]] = []
    try:
        for source in sources:
            if source.resolve().parent != root:
                raise RuntimeError(f"Refusing path outside audio root: {source}")
            if args.check_only:
                measured = run_loudnorm(source)
                output_i = float(measured["input_i"])
                output_tp = float(measured["input_tp"])
                if not (-24.0 <= output_i <= -17.0):
                    raise RuntimeError(
                        f"{source.name}: loudness {output_i} LUFS is out of range"
                    )
                if output_tp > -2.8:
                    raise RuntimeError(
                        f"{source.name}: true peak {output_tp} dBTP is unsafe"
                    )
                report.append(
                    {
                        "resource": source.stem,
                        "output_lufs": output_i,
                        "output_dbtp": output_tp,
                    }
                )
                continue
            temporary = source.with_name(f".{source.stem}.mastering.tmp.wav")
            before = run_loudnorm(source)
            render_master(source, temporary, before)
            after = run_loudnorm(temporary)
            output_i = float(after["input_i"])
            output_tp = float(after["input_tp"])
            # Highly dynamic raw phrases may become true-peak limited before
            # reaching the nominal target. -24 LUFS remains clearly foreground
            # relative to the distant beds and avoids destructive compression.
            if not (-24.0 <= output_i <= -17.0):
                raise RuntimeError(
                    f"{source.name}: output loudness {output_i} LUFS is out of range"
                )
            if output_tp > -2.8:
                raise RuntimeError(f"{source.name}: output true peak {output_tp} dBTP is unsafe")
            pending.append((source, temporary))
            report.append(
                {
                    "resource": source.stem,
                    "input_lufs": float(before["input_i"]),
                    "input_dbtp": float(before["input_tp"]),
                    "output_lufs": output_i,
                    "output_dbtp": output_tp,
                }
            )

        for source, temporary in pending:
            os.replace(temporary, source)
    finally:
        for _, temporary in pending:
            temporary.unlink(missing_ok=True)
        for temporary in root.glob(".voice_phrase_*.mastering.tmp.wav"):
            temporary.unlink(missing_ok=True)

    json.dump(report, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
