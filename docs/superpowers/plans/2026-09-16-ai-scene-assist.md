# AI Scene Assist Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add authenticated DeepSeek-powered scene generation and natural-language adjustment endpoints that return validated `scene_composition_v2` drafts importable by the existing creation page.

**Architecture:** Keep provider I/O in a small async DeepSeek client, prompt construction and JSON parsing in an AI scene service, and HTTP/Pydantic contracts in a dedicated router/schema module. The service runs outline → arrangement → compile sequentially, validates the final composition with the existing validator, and exposes the same stages individually plus a combined generate and adjust endpoint.

**Tech Stack:** Python 3.12, FastAPI, Pydantic v2, `httpx.AsyncClient`, existing composition validator, pytest/pytest-asyncio, Ruff.

**Spec:** `docs/superpowers/specs/2026-09-16-ai-scene-assist-design.md`

## Global Constraints

- Use the existing `server/.venv/Scripts/python.exe` for all checks.
- Never commit `server/.env`, API keys, audio files, or generated scene packages.
- Preserve `scene_composition_v1/v2` behavior and use `validate_composition` for final output.
- Never let the model invent an audio resource; every generated source must map to an input `source_id` or `resource_key`.
- Return 503 when `DW_DEEPSEEK_API_KEY` is absent and 502 after one provider/validation retry fails.
- Do not modify `DreamWeaver/Models/**`, `DreamWeaver/App/AppState.swift`, or any View.

### Task 1: Add settings and provider client

**Files:**
- Modify: `server/app/core/config.py`
- Create: `server/app/services/deepseek.py`
- Create: `server/.env.example`
- Test: `server/tests/test_deepseek.py`

**Interfaces:**
- `DeepSeekClient(settings: Settings, transport: httpx.AsyncClient | None = None)`
- `await DeepSeekClient.complete(*, system_prompt: str, user_prompt: str, max_tokens: int) -> DeepSeekCompletion`
- `DeepSeekCompletion.content: str`, `.model: str`, `.usage: dict[str, int]`

- [ ] **Step 1: Write failing configuration/client tests**

```python
def test_deepseek_settings_have_safe_defaults(monkeypatch):
    monkeypatch.delenv("DW_DEEPSEEK_API_KEY", raising=False)
    settings = Settings()
    assert settings.deepseek_api_key is None
    assert settings.deepseek_model == "deepseek-v4-pro"

@pytest.mark.asyncio
async def test_client_posts_json_mode_and_returns_content():
    async def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/chat/completions"
        payload = json.loads(request.content)
        assert payload["response_format"] == {"type": "json_object"}
        return httpx.Response(
            200,
            json={
                "model": "deepseek-v4-pro",
                "choices": [{"message": {"content": '{"ok":true}'}}],
                "usage": {"prompt_tokens": 3, "completion_tokens": 2},
            },
        )

    transport = httpx.MockTransport(handler)
    client = DeepSeekClient(Settings(deepseek_api_key="test-key"), transport=transport)
    result = await client.complete(system_prompt="Return JSON", user_prompt="{}", max_tokens=32)
    assert result.content == '{"ok":true}'
```

- [ ] **Step 2: Run `server/.venv/Scripts/python.exe -m pytest server/tests/test_deepseek.py -q` and verify failure**

- [ ] **Step 3: Add optional `deepseek_api_key`, base URL, model, timeout and max retry settings; implement an async HTTP client using `POST {base_url}/chat/completions`, bearer auth, `response_format={"type":"json_object"}`, `stream=False`, and bounded timeout. Raise typed `DeepSeekConfigurationError` for missing key and `DeepSeekProviderError` for non-2xx/malformed responses.**

- [ ] **Step 4: Add `server/.env.example` with empty `DW_DEEPSEEK_API_KEY=` and documented non-secret defaults; ensure `.env` remains ignored.**

- [ ] **Step 5: Run the focused tests and Ruff; expect PASS and no network calls.**

- [ ] **Step 6: Stop for diff review and atomic commit**

### Task 2: Define AI scene contracts and prompt templates

**Files:**
- Create: `server/app/schemas/ai_scene.py`
- Create: `server/app/services/ai_scene_prompts.py`
- Test: `server/tests/test_ai_scene_contracts.py`

**Interfaces:**
- Pydantic models: `SelectedSourceIn`, `SceneAssistOptions`, `OutlineRequest`, `ArrangementRequest`, `CompileRequest`, `GenerateRequest`, `AdjustRequest`, `SceneOutline`, `ArrangementPlan`, `SceneAssistResult`, `SceneAdjustResult`.
- `build_outline_prompts(request) -> tuple[str, str]`
- `build_arrangement_prompts(request) -> tuple[str, str]`
- `build_compile_prompts(request) -> tuple[str, str]`
- `build_adjust_prompts(request) -> tuple[str, str]`

- [ ] **Step 1: Write failing model tests for required source fields, angle/radius ranges, stage sections, and JSON-only prompt instructions.**

- [ ] **Step 2: Run focused tests and confirm failure.**

- [ ] **Step 3: Implement strict Pydantic contracts. Use radians for angles, `[0, 1]` for radius/envelope/volume, non-negative times, `end_seconds > start_seconds`, and bounded fade milliseconds. Keep stage outputs separate from final composition.**

- [ ] **Step 4: Implement prompts that embed the v1.2 role rules, v1.1 time/space rules, selected source catalog, and an explicit minimal JSON example. Add anti-invention and safety constraints.**

- [ ] **Step 5: Run focused tests and Ruff; expect PASS.**

- [ ] **Step 6: Stop for diff review and atomic commit**

### Task 3: Implement generation, validation, and adjustment service

**Files:**
- Create: `server/app/services/ai_scene.py`
- Test: `server/tests/test_ai_scene_service.py`

**Interfaces:**
- `await generate_outline(client, request) -> SceneOutline`
- `await generate_arrangement(client, request) -> ArrangementPlan`
- `await compile_scene(client, request) -> SceneAssistResult`
- `await generate_scene(client, request) -> SceneAssistResult`
- `await adjust_scene(client, request) -> SceneAdjustResult`

- [ ] **Step 1: Write failing service tests with a fake client returning deterministic JSON for all four operations. Cover source reference rejection, composition validation, one repair retry, and adjustment change summary.**

- [ ] **Step 2: Run focused tests and confirm failure.**

- [ ] **Step 3: Implement JSON decoding and typed validation. Build the final v2 document from model output, map source references to input UUIDs/resource keys, add stable UUIDs for missing generated IDs, and call `validate_composition`.**

- [ ] **Step 4: Implement one repair attempt by sending the validation error summary back to DeepSeek with the original JSON; raise `SceneAssistGenerationError` after the configured retry count.**

- [ ] **Step 5: Implement `/generate` orchestration and adjustment. Adjustment must return a complete scene package, not a free-form patch, and must preserve unchanged source references.**

- [ ] **Step 6: Run focused tests and Ruff; expect PASS.**

- [ ] **Step 7: Stop for diff review and atomic commit**

### Task 4: Expose authenticated FastAPI endpoints

**Files:**
- Create: `server/app/api/v1/ai_scene.py`
- Modify: `server/app/api/v1/router.py`
- Test: `server/tests/test_ai_scene_api.py`

**Interfaces:**
- `POST /v1/ai/scene-assist/outline`
- `POST /v1/ai/scene-assist/arrangement`
- `POST /v1/ai/scene-assist/compile`
- `POST /v1/ai/scene-assist/generate`
- `POST /v1/ai/scene-assist/adjust`

- [ ] **Step 1: Write failing API tests using the existing auth fixture and monkeypatched service/client. Cover 401, 503 missing key, 502 provider/validation failure, and successful response shapes.**

- [ ] **Step 2: Run focused tests and confirm failure.**

- [ ] **Step 3: Add the router with `CurrentUser`, construct the configured client per request, translate typed service errors to stable HTTP details, and include the router in `server/app/api/v1/router.py`.**

- [ ] **Step 4: Run API tests and the complete server test suite; expect PASS.**

- [ ] **Step 5: Run Ruff and `git diff --check`; expect clean output.**

- [ ] **Step 6: Stop for diff review and atomic commit**

### Task 5: Publish frontend handoff and verification notes

**Files:**
- Create: `docs/ai-scene-assist-api.md`
- Modify: `server/README.md`
- Test/verify: `server/.env.example`, OpenAPI route smoke test

- [ ] **Step 1: Document request/response JSON examples for each endpoint, import mapping to `draft_composition`, error codes, stage sequencing, and the exact secret locations (`server/.env` or deployment Secret `DW_DEEPSEEK_API_KEY`).**

- [ ] **Step 2: Document that `scene_composition_v2` output is draft-only until asset QC, license, and mobile listening checks pass.**

- [ ] **Step 3: Run `server/.venv/Scripts/python.exe -m pytest`, `server/.venv/Scripts/python.exe -m ruff check server/app server/tests`, and an OpenAPI import smoke test.**

- [ ] **Step 4: Stop and report verified, unverified, dangerous-zone, commit, push, and PR instructions.**
