from __future__ import annotations

import uuid

from app.services.seed_catalog import DEFAULT_SCENE_ID
from app.services.timeline import (
    CUE_FIRST_PHRASE_ID,
    PHRASE_MOM_ID,
    VOICE_TRACK_ID,
)


async def test_scene_timeline_hair_care(client) -> None:
    response = await client.get(f"/v1/scenes/{DEFAULT_SCENE_ID}/timeline")
    assert response.status_code == 200
    body = response.json()
    assert body["scene_id"] == str(DEFAULT_SCENE_ID)
    assert body["version"] >= 1
    assert body["automation_mode"] == "official_auto"
    assert body["override_policy"] == "per_source_manual_exit"
    assert body["duration_hint_seconds"] is not None

    phrase_ids = {item["id"] for item in body["phrases"]}
    assert str(PHRASE_MOM_ID) in phrase_ids
    mom = next(p for p in body["phrases"] if p["id"] == str(PHRASE_MOM_ID))
    assert mom["review_status"] == "approved"
    assert mom["voice_binding"]["resource_key"] == "voice_phrase_mom"
    assert mom["voice_binding"]["track_id"] == str(VOICE_TRACK_ID)

    cue_ids = {item["id"] for item in body["cues"]}
    assert str(CUE_FIRST_PHRASE_ID) in cue_ids
    first = next(c for c in body["cues"] if c["id"] == str(CUE_FIRST_PHRASE_ID))
    assert first["at_seconds"] == 6.0
    assert first["actions"][0]["type"] == "play_phrase"
    assert first["actions"][0]["phrase_id"] == str(PHRASE_MOM_ID)

    assert any(c.get("repeat_every_seconds") == 28.0 for c in body["cues"])
    assert any(c.get("progress") == 0.85 for c in body["cues"])


async def test_scene_timeline_missing_scene(client) -> None:
    missing = uuid.UUID("00000000-0000-4000-8000-000000000099")
    response = await client.get(f"/v1/scenes/{missing}/timeline")
    assert response.status_code == 404


async def test_scene_timeline_idempotent(client) -> None:
    first = await client.get(f"/v1/scenes/{DEFAULT_SCENE_ID}/timeline")
    second = await client.get(f"/v1/scenes/{DEFAULT_SCENE_ID}/timeline")
    assert first.status_code == 200
    assert second.status_code == 200
    assert first.json()["version"] == second.json()["version"]
    assert first.json()["cues"] == second.json()["cues"]
