"""Review enable/disable must update scene tracks and timeline together."""

import json
import uuid
from pathlib import Path

import pytest

from app.core.config import Settings, get_settings
from app.models.content import SceneTrack
from app.schemas.content import SceneTimelineOut
from app.services.handoff_presets import FIREPLACE_SCENE_ID, FIXTURES, MIST_SCENE_ID


@pytest.fixture(params=[FIREPLACE_SCENE_ID, MIST_SCENE_ID], ids=["fireplace", "mist"])
def review_case(request):
    scene_id = request.param
    preset = json.loads(FIXTURES[scene_id].read_text(encoding="utf-8"))
    legacy_name = "炉边低语" if scene_id == FIREPLACE_SCENE_ID else "星期天"
    return f"/v1/scenes/{scene_id}", preset, legacy_name


@pytest.fixture
def review_settings(monkeypatch):
    def configure(environment="development", enabled=True):
        monkeypatch.setenv("DW_ENVIRONMENT", environment)
        monkeypatch.setenv("DW_ENABLE_HANDOFF_REVIEW_PRESETS", str(enabled).lower())
        get_settings.cache_clear()

    yield configure
    get_settings.cache_clear()


@pytest.mark.parametrize("environment", ["development", "local", "test", "production", "staging"])
def test_review_requires_opt_in_and_development_environment(environment):
    assert not Settings(
        environment=environment, enable_handoff_review_presets=False
    ).handoff_review_presets_enabled
    settings = Settings(environment=environment, enable_handoff_review_presets=True)
    assert settings.handoff_review_presets_enabled == (
        environment in {"development", "local", "test"}
    )


@pytest.mark.parametrize("fixture", FIXTURES.values(), ids=["fireplace", "mist"])
def test_review_fixture_is_identical_in_backend_and_ios(fixture):
    root = Path(__file__).resolve().parents[2]
    app_fixture = root / "DreamWeaver/Resources/Mock" / fixture.name
    assert fixture.read_bytes() == app_fixture.read_bytes()


async def assert_review(client, review_case):
    url, preset, _ = review_case
    detail = await client.get(url)
    assert detail.status_code == 200
    scene = detail.json()
    assert scene["name"] == preset["name"]
    assert scene["recommended_duration_seconds"] == preset["timeline"]["duration_hint_seconds"]
    assert scene["is_demo_playable"] is True
    assert len(scene["tracks"]) == len(preset["sources"])
    for actual, source in zip(scene["tracks"], preset["sources"], strict=True):
        assert actual["id"] == source["id"]
        assert actual["resource_key"] == source["resourceName"]
        assert actual["layer"] == source["layer"]
        assert actual["position"] == source["position"]
        assert actual["initial_envelope"] == source["initialEnvelope"]
        assert actual["loop"] == (source["resourceName"] in preset["loopCrossfades"])
        assert actual["enabled_by_default"] == source["isEnabled"]
    summaries = (await client.get("/v1/scenes")).json()
    summary = next(item for item in summaries if item["id"] == preset["sceneID"])
    assert summary["name"] == preset["name"]
    timeline = await client.get(url + "/timeline")
    assert timeline.status_code == 200
    expected = SceneTimelineOut.model_validate(preset["timeline"]).model_dump(mode="json")
    assert timeline.json() == expected
    return scene


async def test_old_catalog_upgrades_and_rolls_back_without_reseed(
    client, review_settings, review_case
):
    url, _, legacy_name = review_case
    review_settings(enabled=False)
    original = (await client.get(url)).json()
    assert original["name"] == legacy_name
    rain_url = "/v1/scenes/a1111111-1111-4111-8111-111111111102"
    rain = (await client.get(rain_url)).json()

    review_settings()
    updated = await assert_review(client, review_case)
    assert await assert_review(client, review_case) == updated
    assert (await client.get(rain_url)).json() == rain

    review_settings(enabled=False)
    assert (await client.get(url)).json() == original
    timeline = (await client.get(url + "/timeline")).json()
    assert timeline["version"] == 2
    assert timeline["cues"] == []
    assert timeline["duration_hint_seconds"] == 2700


async def test_fresh_review_seed_and_missing_track_repair_are_idempotent(
    client, review_settings, review_case
):
    review_settings()
    original = await assert_review(client, review_case)
    response = await client.post("/v1/admin/reseed-catalog")
    assert response.status_code == 200
    assert await assert_review(client, review_case) == original

    factory = client._transport.app.state.session_factory
    async with factory() as session:
        track = await session.get(SceneTrack, uuid.UUID(original["tracks"][0]["id"]))
        assert track is not None
        await session.delete(track)
        await session.commit()
    assert await assert_review(client, review_case) == original


@pytest.mark.parametrize("environment", ["production", "staging"])
async def test_disallowed_environment_clears_existing_review_rows(
    client, review_settings, environment, review_case
):
    url, _, legacy_name = review_case
    review_settings()
    await assert_review(client, review_case)

    review_settings(environment=environment, enabled=True)
    detail = (await client.get(url)).json()
    assert detail["name"] == legacy_name
    assert all(
        not (track["resource_key"] or "").startswith("handoff_") for track in detail["tracks"]
    )
    timeline = (await client.get(url + "/timeline")).json()
    assert timeline["version"] == 2
    assert not timeline["cues"]
