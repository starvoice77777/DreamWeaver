from app.services.seed_catalog import DEFAULT_SCENE_ID


async def _login(client, sub: str = "phase3-tester", nickname: str = "测试者") -> dict:
    response = await client.post(
        "/v1/auth/apple",
        json={"identity_token": f"dev:{sub}", "nickname": nickname},
    )
    assert response.status_code == 200, response.text
    return response.json()


def _auth_header(tokens: dict) -> dict[str, str]:
    return {"Authorization": f"Bearer {tokens['access_token']}"}


async def test_home_requires_auth(client) -> None:
    response = await client.get("/v1/home")
    assert response.status_code == 401


async def test_home_favorites_and_recent(client) -> None:
    tokens = await _login(client)
    headers = _auth_header(tokens)

    patch = await client.patch(
        f"/v1/users/me/scene-states/{DEFAULT_SCENE_ID}",
        headers=headers,
        json={"is_favorite": True, "mark_opened": True},
    )
    assert patch.status_code == 200
    state = patch.json()
    assert state["is_favorite"] is True
    assert state["listen_count"] == 1

    home = await client.get("/v1/home", headers=headers)
    assert home.status_code == 200
    body = home.json()
    assert body["greeting_scene_id"] == str(DEFAULT_SCENE_ID)
    assert any(item["id"] == str(DEFAULT_SCENE_ID) for item in body["favorites"])
    assert any(item["id"] == str(DEFAULT_SCENE_ID) for item in body["recent"])
    assert body["recommended"]


async def test_private_scene_copy_draft_save(client) -> None:
    tokens = await _login(client, sub="private-owner")
    headers = _auth_header(tokens)

    copied = await client.post(f"/v1/scenes/{DEFAULT_SCENE_ID}/copy", headers=headers)
    assert copied.status_code == 200
    scene = copied.json()
    assert scene["source_scene_id"] == str(DEFAULT_SCENE_ID)
    assert scene["has_saved_version"] is False
    assert len(scene["draft_sources"]) >= 3
    scene_id = scene["id"]

    draft = await client.put(
        f"/v1/users/me/scenes/{scene_id}/draft",
        headers=headers,
        json={"name": "洗头陪伴改", "sources": scene["draft_sources"][:2]},
    )
    assert draft.status_code == 200
    assert draft.json()["name"] == "洗头陪伴改"
    assert len(draft.json()["draft_sources"]) == 2

    saved = await client.post(f"/v1/users/me/scenes/{scene_id}/save", headers=headers)
    assert saved.status_code == 200
    body = saved.json()
    assert body["has_saved_version"] is True
    assert body["saved_version"] == 1
    assert body["saved_sources"] is not None

    listed = await client.get("/v1/users/me/scenes", headers=headers)
    assert listed.status_code == 200
    assert any(item["id"] == scene_id for item in listed.json())


async def test_blank_private_scene_empty_save_rejected(client) -> None:
    tokens = await _login(client, sub="blank-owner")
    headers = _auth_header(tokens)

    created = await client.post(
        "/v1/users/me/scenes",
        headers=headers,
        json={"name": "空白草稿"},
    )
    assert created.status_code == 200
    scene_id = created.json()["id"]

    saved = await client.post(f"/v1/users/me/scenes/{scene_id}/save", headers=headers)
    assert saved.status_code == 422


async def test_settings_and_refresh_logout(client) -> None:
    tokens = await _login(client, sub="settings-user")
    headers = _auth_header(tokens)

    updated = await client.put(
        "/v1/users/me/settings",
        headers=headers,
        json={"auto_play_enabled": False, "audio_quality": "高"},
    )
    assert updated.status_code == 200
    assert updated.json()["auto_play_enabled"] is False
    assert updated.json()["audio_quality"] == "高"

    refreshed = await client.post(
        "/v1/auth/refresh",
        json={"refresh_token": tokens["refresh_token"]},
    )
    assert refreshed.status_code == 200
    new_tokens = refreshed.json()
    assert new_tokens["access_token"] != tokens["access_token"]

    # Old access token should fail after refresh revoked the session.
    old_home = await client.get("/v1/home", headers=headers)
    assert old_home.status_code == 401

    new_headers = _auth_header(new_tokens)
    home = await client.get("/v1/home", headers=new_headers)
    assert home.status_code == 200

    logout = await client.post("/v1/auth/logout", headers=new_headers)
    assert logout.status_code == 204
    after = await client.get("/v1/home", headers=new_headers)
    assert after.status_code == 401
