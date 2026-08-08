from __future__ import annotations

TRACK_ID = "e5555555-5555-4555-8555-555555555510"
GROUP_ID = "e5555555-5555-4555-8555-555555555520"
CLIP_ID = "e5555555-5555-4555-8555-555555555521"
SECOND_CLIP_ID = "e5555555-5555-4555-8555-555555555522"


def _valid_composition(*, end_seconds: float = 120.0, keyframes: list[dict] | None = None) -> dict:
    return {
        "schema": "scene_composition_v1",
        "version": 1,
        "duration_seconds": 1.0,
        "tracks": [
            {
                "id": TRACK_ID,
                "asset_id": None,
                "resource_key": "rain_soft",
                "layer": "ambience",
                "loop": True,
                "start_seconds": 0.0,
                "end_seconds": end_seconds,
                "source_duration_seconds": 30.0,
                "keyframes": keyframes
                or [
                    {"t": 0.0, "angle": 0.5, "radius": 0.8},
                    {"t": end_seconds / 2, "angle": 2.0, "radius": 0.35},
                ],
            }
        ],
    }


def _valid_v2_composition() -> dict:
    return {
        "schema": "scene_composition_v2",
        "version": 1,
        "duration_seconds": 120.0,
        "source_groups": [
            {
                "id": GROUP_ID,
                "name": "轻声陪伴",
                "symbol_name": "quote.bubble.fill",
                "layer": "voice",
                "display_policy": "while_active",
                "position_keyframes": [
                    {
                        "t": 0.0,
                        "angle": 3.1,
                        "radius": 0.38,
                        "interpolation": "linear",
                    },
                    {
                        "t": 120.0,
                        "angle": -3.1,
                        "radius": 0.8,
                        "interpolation": "smoothstep",
                    },
                ],
            }
        ],
        "clips": [
            {
                "id": CLIP_ID,
                "source_group_id": GROUP_ID,
                "resource_key": "voice_phrase_01",
                "start_seconds": 3.0,
                "end_seconds": 7.1,
                "source_offset_seconds": 0,
                "playback_mode": "oneshot",
                "crossfade_ms": 0,
            }
        ],
    }


async def _login(client, sub: str = "composition-user") -> dict:
    response = await client.post(
        "/v1/auth/apple",
        json={"identity_token": f"dev:{sub}", "nickname": "创作"},
    )
    assert response.status_code == 200, response.text
    return response.json()


def test_validate_composition_rewrites_duration() -> None:
    from app.services.composition import validate_composition

    out = validate_composition(_valid_composition(end_seconds=90.0))
    assert out["duration_seconds"] == 90.0
    assert out["tracks"][0]["id"] == TRACK_ID
    assert out["tracks"][0]["resource_key"] == "rain_soft"


def test_validate_composition_rejects_non_increasing_keyframes() -> None:
    from app.services.composition import CompositionValidationError, validate_composition

    doc = _valid_composition(
        keyframes=[
            {"t": 0.0, "angle": 0.0, "radius": 0.5},
            {"t": 0.0, "angle": 1.0, "radius": 0.5},
        ]
    )
    try:
        validate_composition(doc)
        raise AssertionError("expected CompositionValidationError")
    except CompositionValidationError as exc:
        assert "strictly increasing" in exc.message
        assert exc.track_id == TRACK_ID
        assert exc.keyframe_index == 1


def test_validate_composition_rejects_missing_asset_ref() -> None:
    from app.services.composition import CompositionValidationError, validate_composition

    doc = _valid_composition()
    doc["tracks"][0]["resource_key"] = None
    doc["tracks"][0]["asset_id"] = None
    try:
        validate_composition(doc)
        raise AssertionError("expected CompositionValidationError")
    except CompositionValidationError as exc:
        assert "asset_id or resource_key" in exc.message


def test_validate_composition_rejects_empty_tracks() -> None:
    from app.services.composition import CompositionValidationError, validate_composition

    try:
        validate_composition(
            {"schema": "scene_composition_v1", "version": 1, "duration_seconds": 0, "tracks": []}
        )
        raise AssertionError("expected CompositionValidationError")
    except CompositionValidationError as exc:
        assert "non-empty" in exc.message


def test_validate_v2_preserves_group_clip_identity() -> None:
    from app.services.composition import validate_composition

    out = validate_composition(_valid_v2_composition())
    assert out["schema"] == "scene_composition_v2"
    assert out["source_groups"][0]["id"] == GROUP_ID
    assert out["clips"][0]["source_group_id"] == GROUP_ID
    assert out["source_groups"][0]["position_keyframes"][1]["interpolation"] == "smoothstep"


def test_validate_v2_accepts_multiple_disjoint_clips_for_one_group() -> None:
    from app.services.composition import validate_composition

    doc = _valid_v2_composition()
    second = dict(doc["clips"][0])
    second.update(
        {
            "id": SECOND_CLIP_ID,
            "resource_key": "voice_phrase_02",
            "start_seconds": 12.0,
            "end_seconds": 16.5,
        }
    )
    doc["clips"].append(second)

    out = validate_composition(doc)
    assert len(out["source_groups"]) == 1
    assert [clip["source_group_id"] for clip in out["clips"]] == [GROUP_ID, GROUP_ID]
    assert out["source_groups"][0]["display_policy"] == "while_active"


def test_validate_v2_rejects_dangling_group_reference() -> None:
    from app.services.composition import CompositionValidationError, validate_composition

    doc = _valid_v2_composition()
    doc["clips"][0]["source_group_id"] = TRACK_ID
    try:
        validate_composition(doc)
        raise AssertionError("expected CompositionValidationError")
    except CompositionValidationError as exc:
        assert "does not reference" in exc.message


def test_validate_v2_rejects_invalid_interpolation_and_crossfade() -> None:
    from app.services.composition import CompositionValidationError, validate_composition

    bad_interpolation = _valid_v2_composition()
    bad_interpolation["source_groups"][0]["position_keyframes"][0]["interpolation"] = "jump"
    try:
        validate_composition(bad_interpolation)
        raise AssertionError("expected CompositionValidationError")
    except CompositionValidationError as exc:
        assert "interpolation" in exc.message

    bad_crossfade = _valid_v2_composition()
    bad_crossfade["clips"][0]["playback_mode"] = "loop"
    bad_crossfade["clips"][0]["crossfade_ms"] = 3000
    try:
        validate_composition(bad_crossfade)
        raise AssertionError("expected CompositionValidationError")
    except CompositionValidationError as exc:
        assert "half the clip duration" in exc.message

    bad_fade = _valid_v2_composition()
    bad_fade["clips"][0]["fade_out_ms"] = 5000
    try:
        validate_composition(bad_fade)
        raise AssertionError("expected CompositionValidationError")
    except CompositionValidationError as exc:
        assert "fade_out_ms" in exc.message

    overlapping_fades = _valid_v2_composition()
    overlapping_fades["clips"][0]["fade_in_ms"] = 2500
    overlapping_fades["clips"][0]["fade_out_ms"] = 2500
    try:
        validate_composition(overlapping_fades)
        raise AssertionError("expected CompositionValidationError")
    except CompositionValidationError as exc:
        assert "fade_in_ms + fade_out_ms" in exc.message


async def test_compositions_validate_endpoint(client) -> None:
    tokens = await _login(client)
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}

    ok = await client.post(
        "/v1/compositions/validate",
        headers=headers,
        json={"composition": _valid_composition(end_seconds=45.0)},
    )
    assert ok.status_code == 200, ok.text
    assert ok.json()["composition"]["duration_seconds"] == 45.0

    ok_v2 = await client.post(
        "/v1/compositions/validate",
        headers=headers,
        json={"composition": _valid_v2_composition()},
    )
    assert ok_v2.status_code == 200, ok_v2.text
    assert ok_v2.json()["composition"]["clips"][0]["source_group_id"] == GROUP_ID

    bad = await client.post(
        "/v1/compositions/validate",
        headers=headers,
        json={
            "composition": _valid_composition(
                keyframes=[
                    {"t": 10.0, "angle": 0.0, "radius": 0.5},
                    {"t": 5.0, "angle": 1.0, "radius": 0.5},
                ]
            )
        },
    )
    assert bad.status_code == 400, bad.text
    detail = bad.json()["detail"]
    assert detail["track_id"] == TRACK_ID
    assert detail["keyframe_index"] == 1


async def test_private_scene_draft_and_save_composition(client) -> None:
    tokens = await _login(client, sub="composition-save")
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}

    created = await client.post(
        "/v1/users/me/scenes",
        headers=headers,
        json={"name": "创作草稿", "sources": []},
    )
    assert created.status_code == 200, created.text
    scene_id = created.json()["id"]
    assert created.json()["draft_composition"] is None

    draft = await client.put(
        f"/v1/users/me/scenes/{scene_id}/draft",
        headers=headers,
        json={"draft_composition": _valid_composition(end_seconds=60.0)},
    )
    assert draft.status_code == 200, draft.text
    body = draft.json()
    assert body["draft_composition"]["duration_seconds"] == 60.0
    assert body["saved_composition"] is None

    saved = await client.post(f"/v1/users/me/scenes/{scene_id}/save", headers=headers)
    assert saved.status_code == 200, saved.text
    saved_body = saved.json()
    assert saved_body["saved_composition"] is not None
    assert saved_body["saved_composition"]["duration_seconds"] == 60.0
    assert saved_body["saved_version"] == 1

    bad_draft = await client.put(
        f"/v1/users/me/scenes/{scene_id}/draft",
        headers=headers,
        json={
            "draft_composition": {
                "schema": "scene_composition_v1",
                "version": 1,
                "tracks": [
                    {
                        "id": TRACK_ID,
                        "resource_key": "rain_soft",
                        "start_seconds": 0,
                        "end_seconds": 10,
                        "keyframes": [
                            {"t": 20.0, "angle": 0.0, "radius": 0.5},
                        ],
                    }
                ],
            }
        },
    )
    assert bad_draft.status_code == 400, bad_draft.text
    assert bad_draft.json()["detail"]["message"] == "Keyframe t out of track range"


async def test_private_scene_v2_draft_save_round_trip(client) -> None:
    tokens = await _login(client, sub="composition-v2-save")
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}
    created = await client.post(
        "/v1/users/me/scenes",
        headers=headers,
        json={"name": "v2 编排", "sources": [], "composition": _valid_v2_composition()},
    )
    assert created.status_code == 200, created.text
    scene_id = created.json()["id"]
    assert created.json()["draft_composition"]["schema"] == "scene_composition_v2"

    saved = await client.post(f"/v1/users/me/scenes/{scene_id}/save", headers=headers)
    assert saved.status_code == 200, saved.text
    document = saved.json()["saved_composition"]
    assert document["source_groups"][0]["id"] == GROUP_ID
    assert document["clips"][0]["id"] == CLIP_ID
    assert document["clips"][0]["source_group_id"] == GROUP_ID
