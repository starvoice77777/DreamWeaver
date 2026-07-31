from app.services.seed_catalog import DEFAULT_SCENE_ID


async def test_bootstrap_and_scenes(client) -> None:
    bootstrap = await client.get("/v1/bootstrap")
    assert bootstrap.status_code == 200
    payload = bootstrap.json()
    assert payload["api_version"] == "v1"
    assert payload["default_scene_id"] == str(DEFAULT_SCENE_ID)
    assert len(payload["scenes"]) >= 2
    assert payload["greeting"]

    scenes = await client.get("/v1/scenes")
    assert scenes.status_code == 200
    assert any(item["name"] == "洗头陪伴" for item in scenes.json())

    detail = await client.get(f"/v1/scenes/{DEFAULT_SCENE_ID}")
    assert detail.status_code == 200
    body = detail.json()
    assert body["name"] == "洗头陪伴"
    assert len(body["tracks"]) >= 3
    assert body["tracks"][0]["position"]["radius"] > 0

    presets = await client.get(f"/v1/scenes/{DEFAULT_SCENE_ID}/presets")
    assert presets.status_code == 200
    assert any(item["name"] == "洗头轻声" for item in presets.json())


async def test_apple_auth_dev_token(client) -> None:
    response = await client.post(
        "/v1/auth/apple",
        json={"identity_token": "dev:phase2-tester", "nickname": "测试者"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["nickname"] == "测试者"
    assert body["access_token"]
    assert body["refresh_token"]
    assert body["token_type"] == "bearer"
