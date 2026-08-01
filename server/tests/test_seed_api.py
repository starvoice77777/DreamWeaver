from app.services.storage import InMemoryObjectStorage, set_object_storage


async def _login(client, sub: str = "seed-tester") -> dict:
    response = await client.post(
        "/v1/auth/apple",
        json={"identity_token": f"dev:{sub}", "nickname": "种子测试"},
    )
    assert response.status_code == 200, response.text
    return response.json()


def _auth(tokens: dict) -> dict[str, str]:
    return {"Authorization": f"Bearer {tokens['access_token']}"}


async def _create_ready_asset(
    client, headers: dict[str, str], memory: InMemoryObjectStorage
) -> dict:
    created = await client.post(
        "/v1/uploads",
        headers=headers,
        json={
            "filename": "voice.m4a",
            "content_type": "audio/mp4",
            "byte_size": 12,
            "kind": "voice",
            "name": "录音素材",
        },
    )
    assert created.status_code == 200, created.text
    body = created.json()
    memory.put_bytes(body["storage_key"], b"012345678901", "audio/mp4")
    complete = await client.post(
        f"/v1/uploads/{body['upload_id']}/complete",
        headers=headers,
        params={"duration_seconds": 8},
    )
    assert complete.status_code == 200, complete.text
    return complete.json()


async def test_seed_happy_path(client) -> None:
    memory = InMemoryObjectStorage()
    set_object_storage(memory)
    try:
        tokens = await _login(client)
        headers = _auth(tokens)

        auth = await client.post(
            "/v1/voice-authorizations",
            headers=headers,
            json={"confirmed": True},
        )
        assert auth.status_code == 200, auth.text
        auth_id = auth.json()["id"]
        assert auth.json()["revoked_at"] is None

        listed = await client.get("/v1/voice-authorizations", headers=headers)
        assert listed.status_code == 200
        assert any(item["id"] == auth_id for item in listed.json())

        analyze = await client.post(
            "/v1/seeds/analyze",
            headers=headers,
            json={"duration_seconds": 8},
        )
        assert analyze.status_code == 200
        assert analyze.json()["passed"] is True

        asset = await _create_ready_asset(client, headers, memory)

        process = await client.post(
            "/v1/seeds/process",
            headers=headers,
            json={"authorization_id": auth_id, "source_asset_id": asset["id"]},
        )
        assert process.status_code == 200, process.text
        job = process.json()
        job_id = job["id"]
        assert job["status"] == "processing"
        assert job["progress"] == 0.0
        assert job["preview_storage_key"] == f"generated/{job_id}/preview.m4a"

        # Poll advances stub progress until completed (3 steps of 0.34).
        status = "processing"
        progress = 0.0
        for _ in range(5):
            polled = await client.get(f"/v1/seeds/jobs/{job_id}", headers=headers)
            assert polled.status_code == 200, polled.text
            body = polled.json()
            status = body["status"]
            progress = body["progress"]
            if status == "completed":
                break
        assert status == "completed"
        assert progress == 1.0

        finalized = await client.post(
            f"/v1/seeds/jobs/{job_id}/finalize",
            headers=headers,
            json={"name": "妈妈的声音", "relation": "家人"},
        )
        assert finalized.status_code == 200, finalized.text
        seed = finalized.json()
        assert seed["kind"] == "voice"
        assert seed["name"] == "妈妈的声音"

        library = await client.get("/v1/library/assets", headers=headers)
        assert any(item["id"] == seed["id"] for item in library.json())

        # Idempotent finalize returns same asset.
        again = await client.post(
            f"/v1/seeds/jobs/{job_id}/finalize",
            headers=headers,
            json={"name": "ignored", "relation": "家人"},
        )
        assert again.status_code == 200
        assert again.json()["id"] == seed["id"]
    finally:
        set_object_storage(None)


async def test_revoked_authorization_blocks_process(client) -> None:
    memory = InMemoryObjectStorage()
    set_object_storage(memory)
    try:
        tokens = await _login(client, sub="seed-revoke")
        headers = _auth(tokens)

        auth = await client.post(
            "/v1/voice-authorizations",
            headers=headers,
            json={"confirmed": True},
        )
        auth_id = auth.json()["id"]
        revoke = await client.post(
            f"/v1/voice-authorizations/{auth_id}/revoke",
            headers=headers,
        )
        assert revoke.status_code == 200
        assert revoke.json()["revoked_at"] is not None

        asset = await _create_ready_asset(client, headers, memory)
        process = await client.post(
            "/v1/seeds/process",
            headers=headers,
            json={"authorization_id": auth_id, "source_asset_id": asset["id"]},
        )
        assert process.status_code == 409
    finally:
        set_object_storage(None)


async def test_delete_unfinished_job(client) -> None:
    memory = InMemoryObjectStorage()
    set_object_storage(memory)
    try:
        tokens = await _login(client, sub="seed-delete")
        headers = _auth(tokens)
        auth = await client.post(
            "/v1/voice-authorizations",
            headers=headers,
            json={"confirmed": True},
        )
        asset = await _create_ready_asset(client, headers, memory)
        process = await client.post(
            "/v1/seeds/process",
            headers=headers,
            json={
                "authorization_id": auth.json()["id"],
                "source_asset_id": asset["id"],
            },
        )
        job_id = process.json()["id"]
        deleted = await client.delete(f"/v1/seeds/jobs/{job_id}", headers=headers)
        assert deleted.status_code == 204
        missing = await client.get(f"/v1/seeds/jobs/{job_id}", headers=headers)
        assert missing.status_code == 404
    finally:
        set_object_storage(None)


async def test_analyze_short_sample_fails(client) -> None:
    tokens = await _login(client, sub="seed-analyze")
    response = await client.post(
        "/v1/seeds/analyze",
        headers=_auth(tokens),
        json={"duration_seconds": 1},
    )
    assert response.status_code == 200
    assert response.json()["passed"] is False


async def test_revoke_cascades_jobs_and_finalized_assets(client) -> None:
    memory = InMemoryObjectStorage()
    set_object_storage(memory)
    try:
        tokens = await _login(client, sub="seed-cascade")
        headers = _auth(tokens)

        auth = await client.post(
            "/v1/voice-authorizations",
            headers=headers,
            json={"confirmed": True},
        )
        auth_id = auth.json()["id"]
        source = await _create_ready_asset(client, headers, memory)

        process = await client.post(
            "/v1/seeds/process",
            headers=headers,
            json={"authorization_id": auth_id, "source_asset_id": source["id"]},
        )
        job_id = process.json()["id"]
        for _ in range(5):
            polled = await client.get(f"/v1/seeds/jobs/{job_id}", headers=headers)
            if polled.json()["status"] == "completed":
                break

        finalized = await client.post(
            f"/v1/seeds/jobs/{job_id}/finalize",
            headers=headers,
            json={"name": "将撤回的种子", "relation": "家人"},
        )
        assert finalized.status_code == 200, finalized.text
        seed_id = finalized.json()["id"]

        revoke = await client.post(
            f"/v1/voice-authorizations/{auth_id}/revoke",
            headers=headers,
        )
        assert revoke.status_code == 200, revoke.text
        body = revoke.json()
        assert body["revoked_at"] is not None
        assert body["cancelled_jobs"] >= 1
        assert body["deleted_assets"] >= 1
        assert body["provider_deletes"] >= 1

        listed = await client.get("/v1/library/assets", headers=headers)
        assert all(item["id"] != seed_id for item in listed.json())

        missing_job = await client.get(f"/v1/seeds/jobs/{job_id}", headers=headers)
        assert missing_job.status_code == 404

        # Process blocked after revoke.
        again = await client.post(
            "/v1/seeds/process",
            headers=headers,
            json={"authorization_id": auth_id, "source_asset_id": source["id"]},
        )
        assert again.status_code == 409
    finally:
        set_object_storage(None)
