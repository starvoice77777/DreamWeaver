from __future__ import annotations

import uuid

from app.services.seed_catalog import DEFAULT_SCENE_ID
from app.services.timeline import (
    CUE_FIRST_PHRASE_ID,
    CUE_RAIN_SETTLE_ID,
    PHRASE_MOM_ID,
    VOICE_TRACK_ID,
)

RAIN_EAVES_ID = uuid.UUID("a1111111-1111-4111-8111-111111111102")


async def _login(client, sub: str = "timeline-user") -> dict:
    response = await client.post(
        "/v1/auth/apple",
        json={"identity_token": f"dev:{sub}", "nickname": "时间线"},
    )
    assert response.status_code == 200, response.text
    return response.json()


async def test_scene_timeline_hair_care(client) -> None:
    response = await client.get(f"/v1/scenes/{DEFAULT_SCENE_ID}/timeline")
    assert response.status_code == 200
    body = response.json()
    assert body["scene_id"] == str(DEFAULT_SCENE_ID)
    assert body["version"] >= 1
    assert body["automation_mode"] == "official_auto"
    assert body["override_policy"] == "per_source_manual_exit"
    assert body["manual_override_track_ids"] == []
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


async def test_scene_timeline_rain_eaves(client) -> None:
    response = await client.get(f"/v1/scenes/{RAIN_EAVES_ID}/timeline")
    assert response.status_code == 200
    body = response.json()
    assert body["scene_id"] == str(RAIN_EAVES_ID)
    assert body["phrases"] == []
    assert any(c["id"] == str(CUE_RAIN_SETTLE_ID) for c in body["cues"])
    assert any(a["type"] == "set_volume" for c in body["cues"] for a in c["actions"])


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


async def test_private_scene_copy_draft_save_timeline(client) -> None:
    tokens = await _login(client)
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}

    copied = await client.post(f"/v1/scenes/{DEFAULT_SCENE_ID}/copy", headers=headers)
    assert copied.status_code == 200, copied.text
    body = copied.json()
    scene_id = body["id"]
    assert body["draft_timeline"] is not None
    assert body["draft_timeline"]["automation_mode"] == "official_auto"
    assert body["draft_timeline"]["manual_override_track_ids"] == []
    assert any(
        a.get("type") == "play_phrase"
        for c in body["draft_timeline"]["cues"]
        for a in c.get("actions", [])
    )
    assert body["saved_timeline"] is None

    override_id = str(VOICE_TRACK_ID)
    patched = dict(body["draft_timeline"])
    patched["manual_override_track_ids"] = [override_id]
    draft = await client.put(
        f"/v1/users/me/scenes/{scene_id}/draft",
        headers=headers,
        json={
            "sources": body["draft_sources"],
            "draft_timeline": patched,
        },
    )
    assert draft.status_code == 200, draft.text
    assert draft.json()["draft_timeline"]["manual_override_track_ids"] == [override_id]

    saved = await client.post(f"/v1/users/me/scenes/{scene_id}/save", headers=headers)
    assert saved.status_code == 200, saved.text
    saved_body = saved.json()
    assert saved_body["saved_version"] >= 1
    assert saved_body["saved_timeline"] is not None
    assert saved_body["saved_timeline"]["manual_override_track_ids"] == [override_id]
    assert saved_body["saved_sources"] is not None
