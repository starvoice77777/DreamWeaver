from __future__ import annotations

import uuid

from app.services.seed_catalog import DEFAULT_SCENE_ID
from app.services.timeline import (
    HAIR_CARE_TIMELINE_VERSION,
    RAIN_EAVES_TIMELINE_VERSION,
    VOICE_TRACK_ID,
)

RAIN_EAVES_ID = uuid.UUID("a1111111-1111-4111-8111-111111111102")
FIRST_PHRASE_ID = uuid.UUID("db7992e9-09ee-571d-a58d-2763f9c86ef8")
FIRST_PHRASE_CUE_ID = uuid.UUID("108ddf75-d4f5-52b5-aba3-a357955fa3a2")
RAIN_SOFT_ENTER_CUE_ID = uuid.UUID("f6666666-6666-4666-8666-666666666630")
RAIN_SOFT_TRACK_ID = uuid.UUID("e5555555-5555-4555-8555-555555555510")
RAIN_BAMBOO_TRACK_ID = uuid.UUID("e5555555-5555-4555-8555-555555555512")


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
    assert body["version"] >= HAIR_CARE_TIMELINE_VERSION
    assert body["automation_mode"] == "official_auto"
    assert body["override_policy"] == "per_source_manual_exit"
    assert body["manual_override_track_ids"] == []
    assert body["duration_hint_seconds"] == 620

    assert len(body["phrases"]) == 20
    phrase_ids = {item["id"] for item in body["phrases"]}
    assert str(FIRST_PHRASE_ID) in phrase_ids
    first_phrase = next(p for p in body["phrases"] if p["id"] == str(FIRST_PHRASE_ID))
    assert first_phrase["text"] == "先靠好，什么都不用做。"
    assert first_phrase["review_status"] == "qc_pending"
    assert first_phrase["voice_binding"]["resource_key"] == "voice_phrase_01"
    assert first_phrase["voice_binding"]["track_id"] == str(VOICE_TRACK_ID)
    assert {
        phrase["voice_binding"]["resource_key"] for phrase in body["phrases"]
    } == {f"voice_phrase_{index:02d}" for index in range(1, 21)}
    assert {
        phrase["voice_binding"]["track_id"] for phrase in body["phrases"]
    } == {str(VOICE_TRACK_ID)}

    first = next(c for c in body["cues"] if c["id"] == str(FIRST_PHRASE_CUE_ID))
    assert first["at_seconds"] == 3.0
    first_play = next(a for a in first["actions"] if a["type"] == "play_phrase")
    assert first_play["phrase_id"] == str(FIRST_PHRASE_ID)

    assert any(
        a.get("type") == "play_oneshot" for c in body["cues"] for a in c.get("actions", [])
    )
    assert any(
        a.get("type") == "set_position" for c in body["cues"] for a in c.get("actions", [])
    )
    assert not any(a["type"] == "set_volume" for c in body["cues"] for a in c["actions"])
    # No legacy 28s repeat cadence from pre-v4 placeholder timeline.
    assert not any(c.get("repeat_every_seconds") == 28.0 for c in body["cues"])


async def test_scene_timeline_rain_eaves(client) -> None:
    response = await client.get(f"/v1/scenes/{RAIN_EAVES_ID}/timeline")
    assert response.status_code == 200
    body = response.json()
    assert body["scene_id"] == str(RAIN_EAVES_ID)
    assert body["version"] >= RAIN_EAVES_TIMELINE_VERSION
    assert body["version"] == 9
    assert body["duration_hint_seconds"] == 620
    assert body["phrases"] == []
    assert any(c["id"] == str(RAIN_SOFT_ENTER_CUE_ID) for c in body["cues"])
    assert any(
        a.get("track_id") == str(RAIN_SOFT_TRACK_ID)
        for c in body["cues"]
        for a in c.get("actions", [])
    )
    assert any(
        a.get("track_id") == str(RAIN_BAMBOO_TRACK_ID)
        for c in body["cues"]
        for a in c.get("actions", [])
    )
    assert any(a["type"] == "set_envelope" for c in body["cues"] for a in c["actions"])
    assert any(a["type"] == "enable" for c in body["cues"] for a in c["actions"])
    assert any(a["type"] == "set_position" for c in body["cues"] for a in c["actions"])
    # Package sc_rain_v1 v8: soft fade-in 0.22; parasol enters farther; A04 wind_gust oneshots
    soft_envelopes = [
        a["envelope"]
        for c in body["cues"]
        for a in c.get("actions", [])
        if a.get("type") == "set_envelope" and a.get("track_id") == str(RAIN_SOFT_TRACK_ID)
    ]
    assert 0.22 in soft_envelopes
    parasol_enter = next(
        a
        for c in body["cues"]
        if c["at_seconds"] == 30
        for a in c["actions"]
        if a.get("type") == "set_position"
        and a.get("track_id") == "e5555555-5555-4555-8555-555555555501"
    )
    assert parasol_enter["angle"] == 0.7
    assert parasol_enter["radius"] == 0.62
    oneshots = [
        c
        for c in body["cues"]
        if any(a.get("type") == "play_oneshot" for a in c.get("actions", []))
    ]
    assert len(oneshots) == 2
    assert {c["at_seconds"] for c in oneshots} == {188, 458}
    # Spatial keyframes expanded from package position_keyframes
    positioned_cues = [
        cue
        for cue in body["cues"]
        if any(action["type"] == "set_position" for action in cue["actions"])
    ]
    assert len(positioned_cues) >= 10


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
