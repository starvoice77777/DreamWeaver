"""Portable checks for the review library; the original handoff need not be in Git."""

import csv
import hashlib
import importlib.util
import json
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
AUDIO = ROOT / "DreamWeaver/Resources/Audio"
SPEC = importlib.util.spec_from_file_location("importer", ROOT / "scripts/import_handoff_audio.py")
importer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(importer)
CATALOG = json.loads((AUDIO / "handoff_audio_catalog.json").read_text(encoding="utf-8"))
ENTRIES = CATALOG["entries"]


def test_catalog_is_complete_traceable_and_review_only():
    assert CATALOG["releaseReady"] is False
    assert CATALOG["usage"] == "debug_review_only"
    assert len(ENTRIES) == len({e["id"] for e in ENTRIES}) == 57
    assert {e["id"] for e in ENTRIES} == importer.NAMES.keys()
    assert sum(e["reusedExisting"] for e in ENTRIES) == 4
    for entry in ENTRIES:
        path = AUDIO / entry["file"]
        assert path.stem == entry["resourceKey"]
        assert importer.sha256(path) == entry["outputSHA256"]
        assert entry["assetStatus"] == "qc_pending"
        assert entry["licenseStatus"] == "unreviewed"
        assert entry["durationSeconds"] > 0
    assert {p.name for p in AUDIO.glob("handoff_*.m4a")} == {
        e["file"] for e in ENTRIES if not e["reusedExisting"]
    }


@pytest.mark.parametrize("entry", ENTRIES, ids=lambda entry: entry["id"])
def test_audio_decodes_and_preserves_source_duration(entry):
    result = importer.ffmpeg("-i", AUDIO / entry["file"], "-f", "s16le", "-acodec",
                             "pcm_s16le", "-ar", "48000", "-ac", "2", "-")
    assert any(result.stdout)
    duration = len(result.stdout) / (48000 * 2 * 2)
    assert abs(duration - entry["durationSeconds"]) < 0.05


@pytest.mark.parametrize("invalid", ["hash", "size", "escape"])
def test_import_rejects_tampered_or_external_sources_before_writing(tmp_path, invalid):
    source = tmp_path / "source.wav"
    source.write_bytes(b"original")
    root = tmp_path / "handoff"
    root.mkdir()
    (root / "source.wav").write_bytes(b"original")
    row = dict(relative_path="../source.wav" if invalid == "escape" else "source.wav",
               sha256="0" * 64 if invalid == "hash" else hashlib.sha256(b"original").hexdigest(),
               bytes=1 if invalid == "size" else 8)
    with (root / "audio_asset_index.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=row)
        writer.writeheader()
        writer.writerow(row)
    with pytest.raises(ValueError, match="Invalid source path|Hash/size mismatch"):
        importer.checked_rows(root)
