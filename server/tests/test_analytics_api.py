from __future__ import annotations

import uuid


async def _login(client, sub: str = "analytics-user") -> dict:
    response = await client.post(
        "/v1/auth/apple",
        json={"identity_token": f"dev:{sub}", "nickname": "陪伴统计"},
    )
    assert response.status_code == 200, response.text
    return response.json()


async def test_analytics_requires_auth(client) -> None:
    response = await client.get("/v1/analytics/summary")
    assert response.status_code == 401
    response = await client.post("/v1/analytics/events", json={"events": []})
    assert response.status_code == 401


async def test_analytics_summary_and_events(client) -> None:
    tokens = await _login(client)
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}

    empty = await client.get("/v1/analytics/summary", headers=headers)
    assert empty.status_code == 200, empty.text
    body = empty.json()
    assert body["total_minutes"] == 0
    assert body["week_minutes"] == 0
    assert body["usual_bedtime"] == "23:20"
    assert len(body["sleep_trend"]) == 7
    summary_id = body["id"]

    scene_id = str(uuid.UUID("a1111111-1111-4111-8111-111111111101"))
    posted = await client.post(
        "/v1/analytics/events",
        headers=headers,
        json={
            "events": [
                {"type": "scene_listen", "scene_id": scene_id},
                {
                    "type": "session_ended",
                    "scene_id": scene_id,
                    "duration_seconds": 125,
                    "idempotency_key": "session-1",
                },
                {"type": "mix_edited", "scene_id": scene_id},
            ]
        },
    )
    assert posted.status_code == 200, posted.text
    assert posted.json()["accepted"] == 3
    assert posted.json()["skipped_duplicates"] == 0

    summary = await client.get("/v1/analytics/summary", headers=headers)
    assert summary.status_code == 200
    data = summary.json()
    assert data["id"] == summary_id
    # scene_listen +1, session_ended max(125//60,1)=2 → total 3
    assert data["total_minutes"] == 3
    assert data["week_minutes"] == 3
    assert data["sleep_trend"][-1] == 3
    assert data["last_used_at"] is not None


async def test_analytics_idempotency(client) -> None:
    tokens = await _login(client, sub="analytics-idem")
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}
    scene_id = str(uuid.uuid4())
    payload = {
        "events": [
            {
                "type": "session_ended",
                "scene_id": scene_id,
                "duration_seconds": 60,
                "idempotency_key": "dup-key-1",
            }
        ]
    }
    first = await client.post("/v1/analytics/events", headers=headers, json=payload)
    assert first.status_code == 200
    assert first.json()["accepted"] == 1

    second = await client.post("/v1/analytics/events", headers=headers, json=payload)
    assert second.status_code == 200
    assert second.json()["accepted"] == 0
    assert second.json()["skipped_duplicates"] == 1

    summary = await client.get("/v1/analytics/summary", headers=headers)
    assert summary.json()["total_minutes"] == 1
