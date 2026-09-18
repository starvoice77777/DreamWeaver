"""Review enable/disable must update scene tracks and timeline together."""

import json
from pathlib import Path

import pytest

from app.core.config import Settings, get_settings
from app.schemas.content import SceneTimelineOut
from app.services.handoff_presets import FIREPLACE_SCENE_ID, FIXTURE

URL = f"/v1/scenes/{FIREPLACE_SCENE_ID}"
PRESET = json.loads(FIXTURE.read_text(encoding="utf-8"))


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


def test_review_fixture_is_identical_in_backend_and_ios():
    root = Path(__file__).resolve().parents[2]
    assert FIXTURE.read_bytes() == (root / "DreamWeaver/Resources/Mock" / FIXTURE.name).read_bytes()


async def assert_review(client):
    detail = await client.get(URL)
    assert detail.status_code == 200
    scene = detail.json()
    assert scene["name"] == "炉边静夜" and scene["recommended_duration_seconds"] == 620
    assert scene["is_demo_playable"] is True
    assert len(scene["tracks"]) == 5
    for actual, source in zip(scene["tracks"], PRESET["sources"], strict=True):
        assert actual["id"] == source["id"]
        assert actual["resource_key"] == source["resourceName"]
        assert actual["position"] == source["position"]
        assert actual["initial_envelope"] == 1
        assert actual["loop"] == (source["resourceName"] in PRESET["loopCrossfades"])
        assert actual["enabled_by_default"] == source["isEnabled"]
    timeline = await client.get(URL + "/timeline")
    assert timeline.status_code == 200
    assert timeline.json() == SceneTimelineOut.model_validate(PRESET["timeline"]).model_dump(
        mode="json"
    )
    return scene


async def test_old_catalog_upgrades_and_rolls_back_without_reseed(client, review_settings):
    review_settings(enabled=False)
    original = (await client.get(URL)).json()
    assert original["name"] == "炉边低语"
    rain_url = "/v1/scenes/a1111111-1111-4111-8111-111111111102"
    rain = (await client.get(rain_url)).json()
    review_settings()
    updated = await assert_review(client)
    assert await assert_review(client) == updated
    assert (await client.get(rain_url)).json() == rain
    review_settings(enabled=False)
    assert (await client.get(URL)).json() == original
    timeline = (await client.get(URL + "/timeline")).json()
    assert timeline["version"] == 2 and timeline["cues"] == []
    assert timeline["duration_hint_seconds"] == 2700


async def test_fresh_review_seed_and_reseed_are_idempotent(client, review_settings):
    review_settings()
    original = await assert_review(client)
    response = await client.post("/v1/admin/reseed-catalog")
    assert response.status_code == 200
    assert await assert_review(client) == original


@pytest.mark.parametrize("environment", ["production", "staging"])
async def test_disallowed_environment_clears_existing_review_rows(
    client, review_settings, environment
):
    review_settings()
    await assert_review(client)
    review_settings(environment=environment, enabled=True)
    detail = (await client.get(URL)).json()
    assert detail["name"] == "炉边低语"
    assert all(not (t["resource_key"] or "").startswith("handoff_") for t in detail["tracks"])
    timeline = (await client.get(URL + "/timeline")).json()
    assert timeline["version"] == 2 and not timeline["cues"]
