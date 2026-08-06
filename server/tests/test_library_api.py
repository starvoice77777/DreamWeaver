from app.services.storage import InMemoryObjectStorage, set_object_storage


async def _login(client, sub: str = "upload-tester") -> dict:
    response = await client.post(
        "/v1/auth/apple",
        json={"identity_token": f"dev:{sub}", "nickname": "上传测试"},
    )
    assert response.status_code == 200, response.text
    return response.json()


def _auth(tokens: dict) -> dict[str, str]:
    return {"Authorization": f"Bearer {tokens['access_token']}"}


async def test_upload_complete_list_playback(client) -> None:
    memory = InMemoryObjectStorage()
    set_object_storage(memory)
    try:
        tokens = await _login(client)
        headers = _auth(tokens)

        created = await client.post(
            "/v1/uploads",
            headers=headers,
            json={
                "filename": "clip.m4a",
                "content_type": "audio/mp4",
                "byte_size": 12,
                "kind": "life",
                "name": "测试音",
            },
        )
        assert created.status_code == 200, created.text
        body = created.json()
        upload_id = body["upload_id"]
        storage_key = body["storage_key"]
        assert body["put_url"].startswith("https://memory.local/put/")
        assert "Content-Type" in body["required_headers"]

        # Simulate client PUT to object storage (exactly declared size).
        memory.put_bytes(storage_key, b"012345678901", "audio/mp4")

        complete = await client.post(
            f"/v1/uploads/{upload_id}/complete",
            headers=headers,
            params={"duration_seconds": 42},
        )
        assert complete.status_code == 200, complete.text
        asset = complete.json()
        assert asset["name"] == "测试音"
        assert asset["duration_seconds"] == 42
        assert asset["byte_size"] == 12
        asset_id = asset["id"]

        listed = await client.get("/v1/library/assets", headers=headers)
        assert listed.status_code == 200
        assert any(item["id"] == asset_id for item in listed.json())

        playback = await client.get(
            f"/v1/library/assets/{asset_id}/playback-url",
            headers=headers,
        )
        assert playback.status_code == 200
        assert playback.json()["url"].startswith("https://memory.local/get/")
    finally:
        set_object_storage(None)


async def test_upload_rejects_bad_extension(client) -> None:
    set_object_storage(InMemoryObjectStorage())
    try:
        tokens = await _login(client, sub="bad-ext")
        response = await client.post(
            "/v1/uploads",
            headers=_auth(tokens),
            json={
                "filename": "clip.exe",
                "content_type": "audio/mp4",
                "byte_size": 10,
            },
        )
        assert response.status_code == 422
    finally:
        set_object_storage(None)


async def test_complete_without_object_fails(client) -> None:
    set_object_storage(InMemoryObjectStorage())
    try:
        tokens = await _login(client, sub="missing-object")
        headers = _auth(tokens)
        created = await client.post(
            "/v1/uploads",
            headers=headers,
            json={
                "filename": "a.wav",
                "content_type": "audio/wav",
                "byte_size": 8,
            },
        )
        upload_id = created.json()["upload_id"]
        complete = await client.post(f"/v1/uploads/{upload_id}/complete", headers=headers)
        assert complete.status_code == 400
    finally:
        set_object_storage(None)


async def _create_ready_asset(
    client,
    headers: dict[str, str],
    memory: InMemoryObjectStorage,
    name: str = "素材",
) -> dict:
    created = await client.post(
        "/v1/uploads",
        headers=headers,
        json={
            "filename": "clip.m4a",
            "content_type": "audio/mp4",
            "byte_size": 12,
            "kind": "life",
            "name": name,
        },
    )
    assert created.status_code == 200, created.text
    body = created.json()
    memory.put_bytes(body["storage_key"], b"012345678901", "audio/mp4")
    complete = await client.post(f"/v1/uploads/{body['upload_id']}/complete", headers=headers)
    assert complete.status_code == 200, complete.text
    return complete.json()


async def test_patch_favorite_and_delete_impact(client) -> None:
    memory = InMemoryObjectStorage()
    set_object_storage(memory)
    try:
        tokens = await _login(client, sub="mutate-tester")
        headers = _auth(tokens)
        asset = await _create_ready_asset(client, headers, memory, name="可改名")
        asset_id = asset["id"]

        patched = await client.patch(
            f"/v1/library/assets/{asset_id}",
            headers=headers,
            json={"name": "新名字", "symbol_name": "star.fill"},
        )
        assert patched.status_code == 200, patched.text
        assert patched.json()["name"] == "新名字"
        assert patched.json()["symbol_name"] == "star.fill"
        assert patched.json()["is_favorite"] is False

        fav = await client.post(f"/v1/library/assets/{asset_id}/favorite", headers=headers)
        assert fav.status_code == 200
        assert fav.json()["is_favorite"] is True

        scene = await client.post(
            "/v1/users/me/scenes",
            headers=headers,
            json={
                "name": "含素材场景",
                "sources": [
                    {
                        "name": "引用音",
                        "symbolName": "waveform",
                        "assetId": asset_id,
                        "volume": 0.5,
                    },
                    {"name": "无关音", "symbolName": "drop", "volume": 0.3},
                ],
            },
        )
        assert scene.status_code == 200, scene.text
        scene_id = scene.json()["id"]

        impact = await client.get(
            f"/v1/library/assets/{asset_id}/delete-impact",
            headers=headers,
        )
        assert impact.status_code == 200, impact.text
        impact_body = impact.json()
        assert impact_body["total_references"] == 1
        assert impact_body["affected_scenes"][0]["id"] == scene_id
        assert impact_body["affected_scenes"][0]["draft_reference_count"] == 1

        deleted = await client.delete(f"/v1/library/assets/{asset_id}", headers=headers)
        assert deleted.status_code == 200, deleted.text
        assert deleted.json()["deleted"] is True
        assert scene_id in deleted.json()["scrubbed_scene_ids"]
        assert deleted.json()["storage_deleted"] is True
        assert memory.objects == {}

        listed = await client.get("/v1/library/assets", headers=headers)
        assert listed.status_code == 200
        assert all(item["id"] != asset_id for item in listed.json())

        detail = await client.get(f"/v1/users/me/scenes/{scene_id}", headers=headers)
        assert detail.status_code == 200
        sources = detail.json()["draft_sources"]
        assert len(sources) == 1
        assert sources[0]["name"] == "无关音"
    finally:
        set_object_storage(None)
