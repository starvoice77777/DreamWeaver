"""Official catalog force-refresh (upsert tracks without wiping the DB)."""

from __future__ import annotations

import uuid

from sqlalchemy import select

from app.models.content import SceneTrack
from app.services.seed_catalog import (
    official_preset_specs,
    official_scene_specs,
    reseed_official_catalog,
)

RAIN_SCENE_ID = uuid.UUID("a1111111-1111-4111-8111-111111111102")
BAMBOO_TRACK_ID = uuid.UUID("e5555555-5555-4555-8555-555555555512")
FAR_RAIN_TRACK_ID = uuid.UUID("e5555555-5555-4555-8555-555555555510")
HAIR_CARE_SCENE_ID = uuid.UUID("a1111111-1111-4111-8111-111111111101")
STALE_RAIN_VOICE_TRACK_ID = uuid.UUID("e5555555-5555-4555-8555-555555559999")


def test_official_catalog_avoids_silent_and_stale_runtime_resources() -> None:
    scene_resources = {
        track["resource_key"]
        for scene in official_scene_specs()
        for track in scene["tracks"]
        if track["resource_key"] is not None
    }
    preset_resources = {
        source["resourceName"]
        for preset in official_preset_specs()
        for source in preset["sources"]
    }
    assert "voice_phrase_mom" not in scene_resources | preset_resources
    assert "ac_hum" not in preset_resources


def test_official_catalog_scopes_voice_to_hair_care() -> None:
    for scene in official_scene_specs():
        voice_tracks = [track for track in scene["tracks"] if track["layer"] == "voice"]
        if scene["id"] == HAIR_CARE_SCENE_ID:
            assert len(voice_tracks) == 1
            assert voice_tracks[0]["resource_key"] == "voice_phrase_01"
        else:
            assert voice_tracks == []


async def test_reseed_inserts_missing_bamboo_track(client) -> None:  # noqa: ANN001
    """Simulate an old rain-eaves rowset (3 tracks, stale resource_key) then force-refresh."""
    factory = client._transport.app.state.session_factory  # type: ignore[attr-defined]

    async with factory() as session:
        await reseed_official_catalog(session)

        bamboo = await session.get(SceneTrack, BAMBOO_TRACK_ID)
        assert bamboo is not None
        await session.delete(bamboo)

        far = await session.get(SceneTrack, FAR_RAIN_TRACK_ID)
        assert far is not None
        far.resource_key = "rain_soft_legacy"
        session.add(
            SceneTrack(
                id=STALE_RAIN_VOICE_TRACK_ID,
                scene_id=RAIN_SCENE_ID,
                name="stale voice",
                symbol_name="person.wave.2.fill",
                layer="voice",
                initial_envelope=0.5,
                angle=0,
                radius=0.4,
                resource_key="voice_phrase_01",
                loop=False,
                enabled_by_default=True,
                sort_order=99,
            )
        )
        await session.commit()

    async with factory() as session:
        remaining = list(
            await session.scalars(select(SceneTrack.id).where(SceneTrack.scene_id == RAIN_SCENE_ID))
        )
        assert BAMBOO_TRACK_ID not in remaining
        far = await session.get(SceneTrack, FAR_RAIN_TRACK_ID)
        assert far is not None
        assert far.resource_key == "rain_soft_legacy"
        assert await session.get(SceneTrack, STALE_RAIN_VOICE_TRACK_ID) is not None

    response = await client.post("/v1/admin/reseed-catalog")
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["status"] == "ok"
    assert body["tracks_inserted"] >= 1
    assert body["tracks_updated"] >= 1
    assert body["tracks_deleted"] >= 1

    detail = await client.get(f"/v1/scenes/{RAIN_SCENE_ID}")
    assert detail.status_code == 200
    tracks = {t["id"]: t for t in detail.json()["tracks"]}
    assert str(BAMBOO_TRACK_ID) in tracks
    assert tracks[str(BAMBOO_TRACK_ID)]["resource_key"] == "rain_bamboo_leaf"
    assert tracks[str(FAR_RAIN_TRACK_ID)]["resource_key"] == "rain_soft"
    assert str(STALE_RAIN_VOICE_TRACK_ID) not in tracks


async def test_reseed_forbidden_in_production(client, monkeypatch) -> None:  # noqa: ANN001
    from app.core.config import get_settings

    monkeypatch.setenv("DW_ENVIRONMENT", "production")
    get_settings.cache_clear()
    try:
        response = await client.post("/v1/admin/reseed-catalog")
        assert response.status_code == 403
    finally:
        monkeypatch.delenv("DW_ENVIRONMENT", raising=False)
        get_settings.cache_clear()


async def test_rain_eaves_seeded_with_bamboo(client) -> None:  # noqa: ANN001
    scenes = await client.get("/v1/scenes")
    assert scenes.status_code == 200
    match = next((item for item in scenes.json() if item["id"] == str(RAIN_SCENE_ID)), None)
    assert match is not None
    assert match["visual_style"] == "rainEaves"

    detail = await client.get(f"/v1/scenes/{RAIN_SCENE_ID}")
    assert detail.status_code == 200
    by_name = {t["name"]: t for t in detail.json()["tracks"]}
    assert "竹叶雨" in by_name
    assert by_name["竹叶雨"]["resource_key"] == "rain_bamboo_leaf"
    assert by_name["远雨"]["resource_key"] == "rain_soft"
    assert by_name["檐下雨"]["resource_key"] == "rain_parasol"
    assert by_name["阵风"]["resource_key"] == "wind_gust"
    assert by_name["阵风"]["layer"] == "trigger"
    assert by_name["阵风"]["loop"] is False
