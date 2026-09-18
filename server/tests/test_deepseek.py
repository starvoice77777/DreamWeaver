import json

import httpx
import pytest

from app.core.config import Settings
from app.services.deepseek import DeepSeekClient, DeepSeekProviderError


def test_deepseek_settings_have_safe_defaults(monkeypatch):
    monkeypatch.delenv("DW_DEEPSEEK_API_KEY", raising=False)
    settings = Settings()
    assert settings.deepseek_api_key is None
    assert settings.deepseek_model == "deepseek-v4-pro"
    assert settings.deepseek_timeout_seconds == 90.0
    assert settings.deepseek_max_retries == 1


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "details",
    [
        {},
        {
            "prompt_tokens_details": {"cached_tokens": 1},
            "completion_tokens_details": {"reasoning_tokens": 1},
        },
        {"prompt_tokens_details": None, "completion_tokens_details": None},
    ],
    ids=["flat-usage", "nested-usage-details", "null-usage-details"],
)
async def test_client_posts_json_mode_and_returns_content(details):
    counters = {
        "prompt_tokens": 3,
        "completion_tokens": 2,
        "total_tokens": 5,
        "prompt_cache_hit_tokens": 1,
        "prompt_cache_miss_tokens": 2,
    }

    async def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/chat/completions"
        assert request.headers["authorization"] == "Bearer test-key"
        payload = json.loads(request.content)
        assert payload["response_format"] == {"type": "json_object"}
        assert payload["stream"] is False
        return httpx.Response(
            200,
            json={
                "model": "deepseek-v4-pro",
                "choices": [{"message": {"content": '{"ok":true}'}}],
                "usage": {**counters, **details},
            },
        )

    transport = httpx.MockTransport(handler)
    client = DeepSeekClient(Settings(deepseek_api_key="test-key"), transport=transport)
    result = await client.complete(system_prompt="Return JSON", user_prompt="{}", max_tokens=32)
    assert result.content == '{"ok":true}'
    assert result.model == "deepseek-v4-pro"
    assert result.usage == counters


@pytest.mark.asyncio
async def test_client_rejects_malformed_usage_counter():
    async def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            json={
                "model": "deepseek-v4-pro",
                "choices": [{"message": {"content": '{"ok":true}'}}],
                "usage": {"prompt_tokens": {"invalid": 3}},
            },
        )

    async with DeepSeekClient(
        Settings(_env_file=None, deepseek_api_key="test-key"),
        transport=httpx.MockTransport(handler),
    ) as client:
        with pytest.raises(DeepSeekProviderError, match="malformed response"):
            await client.complete(system_prompt="Return JSON", user_prompt="{}", max_tokens=32)
