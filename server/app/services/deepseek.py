from dataclasses import dataclass
from typing import Any

import httpx

from app.core.config import Settings


class DeepSeekConfigurationError(RuntimeError):
    """Raised when DeepSeek cannot be used with the current configuration."""


class DeepSeekProviderError(RuntimeError):
    """Raised when DeepSeek returns an unusable response."""


@dataclass(frozen=True)
class DeepSeekCompletion:
    content: str
    model: str
    usage: dict[str, int]


class DeepSeekClient:
    def __init__(
        self,
        settings: Settings,
        transport: httpx.AsyncClient | httpx.AsyncBaseTransport | None = None,
    ) -> None:
        self.settings = settings
        self._owns_client = not isinstance(transport, httpx.AsyncClient)
        if self._owns_client:
            self._client = httpx.AsyncClient(
                base_url=settings.deepseek_base_url.rstrip("/"),
                headers={"Authorization": f"Bearer {settings.deepseek_api_key or ''}"},
                timeout=settings.deepseek_timeout_seconds,
                transport=transport,
            )
        else:
            self._client = transport

    async def __aenter__(self) -> "DeepSeekClient":
        return self

    async def __aexit__(self, *_: object) -> None:
        await self.aclose()

    async def aclose(self) -> None:
        if self._owns_client:
            await self._client.aclose()

    async def complete(
        self, *, system_prompt: str, user_prompt: str, max_tokens: int
    ) -> DeepSeekCompletion:
        if not self.settings.deepseek_api_key:
            raise DeepSeekConfigurationError("DW_DEEPSEEK_API_KEY is required")

        payload = {
            "model": self.settings.deepseek_model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            "max_tokens": max_tokens,
            "response_format": {"type": "json_object"},
            "stream": False,
        }
        retries = max(0, self.settings.deepseek_max_retries)
        for attempt in range(retries + 1):
            try:
                response = await self._client.post("/chat/completions", json=payload)
                response.raise_for_status()
                return self._parse_completion(response.json())
            except (httpx.TransportError, httpx.TimeoutException) as exc:
                if attempt >= retries:
                    raise DeepSeekProviderError("DeepSeek request failed") from exc
            except httpx.HTTPStatusError as exc:
                raise DeepSeekProviderError(
                    f"DeepSeek returned HTTP {exc.response.status_code}"
                ) from exc
            except (TypeError, KeyError, ValueError) as exc:
                raise DeepSeekProviderError("DeepSeek returned a malformed response") from exc
        raise AssertionError("unreachable")

    def _parse_completion(self, data: Any) -> DeepSeekCompletion:
        if not isinstance(data, dict):
            raise DeepSeekProviderError("DeepSeek returned a malformed response")
        try:
            model = data["model"]
            content = data["choices"][0]["message"]["content"]
            usage = data["usage"]
            if (
                not isinstance(model, str)
                or not isinstance(content, str)
                or not isinstance(usage, dict)
            ):
                raise TypeError
            # Token breakdowns may be objects or null; usage exposes only flat counters.
            parsed_usage = {
                str(key): int(value)
                for key, value in usage.items()
                if key not in {"prompt_tokens_details", "completion_tokens_details"}
            }
            return DeepSeekCompletion(content=content, model=model, usage=parsed_usage)
        except (IndexError, KeyError, TypeError, ValueError) as exc:
            raise DeepSeekProviderError("DeepSeek returned a malformed response") from exc
