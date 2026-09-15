# AI Scene Assist API（前端交接）

本文档描述 DeepSeek 驱动的 AI 场景辅助接口。接口只生成用户当前编辑会话的草稿数据；它不会自动创建、发布或保存个人场景。

## 基本约定

- Base path：`/v1/ai/scene-assist`
- 鉴权：所有接口都需要 `Authorization: Bearer <access_token>`。
- `Content-Type: application/json`。
- 所有示例中的 `source_id` 仅为示例 UUID；客户端必须传入当前选中的声音目录项。
- `selected_sources` 是模型可用的白名单。服务端会拒绝模型返回未选中的 `source_id`、`resource_key` 或不一致的绑定。
- 输出中的 `composition` 是 `scene_composition_v2`，可直接作为个人场景草稿的 `draft_composition` 值。

## 推荐阶段顺序

```text
选择声音 → POST /outline → POST /arrangement → POST /compile
                                      ↘ POST /generate（一次调用完成上面三步）
已有草稿 → POST /adjust → 人工预览与检查 → PUT .../draft（写入 draft_composition）
```

客户端可以用分阶段接口展示中间结果，也可以用 `generate` 做一次完整生成。`compile` 的请求必须携带此前得到的 `outline` 和 `arrangement`；`adjust` 必须携带当前场景和自然语言修改指令。AI 响应成功后，客户端应先在编辑器中预览，再显式写入个人场景草稿。

## 1. 生成场景大纲

### `POST /v1/ai/scene-assist/outline`

请求：

```json
{
  "selected_sources": [
    {
      "source_id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
      "resource_key": "rain_soft",
      "name": "轻雨",
      "description": "柔和、连续的雨声",
      "layer": "environment",
      "loop": true,
      "duration_seconds": 30,
      "default_volume": 0.3,
      "angle": 0,
      "radius": 0.8
    }
  ],
  "options": {
    "scene_intent": "睡前放松",
    "duration_seconds": 1800,
    "language": "zh-CN",
    "constraints": ["不要加入人声"]
  }
}
```

响应 `200`：

```json
{
  "name": "檐下听雨",
  "subtitle": "安静入睡",
  "description": "以连续雨声为主体的睡前场景。",
  "theme": "rain",
  "use_case_tags": ["sleep", "relax"],
  "composition_profile": "environment_led",
  "foreground_priority": "environment",
  "trigger_focus": "none",
  "duration_policy": "continuous_loop",
  "spatial_policy": "mostly_fixed",
  "trigger_mode": "none",
  "sections": [
    {"name": "main", "description": "稳定雨声", "start_seconds": 0, "end_seconds": 1800, "active_roles": ["bed"]}
  ]
}
```

## 2. 生成轨道编排

### `POST /v1/ai/scene-assist/arrangement`

请求是在 outline 请求上增加 `outline`：

```json
{
  "selected_sources": [{"source_id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "resource_key": "rain_soft", "name": "轻雨", "description": "柔和雨声", "layer": "environment", "loop": true, "duration_seconds": 30, "default_volume": 0.3, "angle": 0, "radius": 0.8}],
  "options": {"duration_seconds": 1800, "language": "zh-CN"},
  "outline": {
    "name": "檐下听雨", "subtitle": "安静入睡", "description": "睡前雨声", "theme": "rain", "use_case_tags": ["sleep"],
    "composition_profile": "environment_led", "foreground_priority": "environment", "trigger_focus": "none", "duration_policy": "continuous_loop", "spatial_policy": "mostly_fixed", "trigger_mode": "none",
    "sections": [{"name": "main", "description": "稳定雨声", "start_seconds": 0, "end_seconds": 1800, "active_roles": ["bed"]}]
  }
}
```

响应 `200`：

```json
{
  "tracks": [
    {
      "source_id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
      "resource_key": "rain_soft",
      "role": "bed",
      "start_seconds": 0,
      "end_seconds": 1800,
      "loop": true,
      "default_volume": 0.3,
      "fade_in_ms": 500,
      "fade_out_ms": 500,
      "keyframes": [{"t": 0, "angle": 0, "radius": 0.8, "interpolation": "smoothstep"}]
    }
  ]
}
```

## 3. 将大纲和编排编译成场景草稿

### `POST /v1/ai/scene-assist/compile`

请求：`arrangement` 是上一步响应，`outline` 是第一步响应；两者与 `selected_sources`、`options` 放在同一层。

```json
{
  "selected_sources": [{"source_id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "resource_key": "rain_soft", "name": "轻雨", "description": "柔和雨声", "layer": "environment", "loop": true, "duration_seconds": 30, "default_volume": 0.3, "angle": 0, "radius": 0.8}],
  "options": {"duration_seconds": 1800, "language": "zh-CN"},
  "outline": {"name": "檐下听雨", "subtitle": "安静入睡", "description": "睡前雨声", "theme": "rain", "use_case_tags": ["sleep"], "composition_profile": "environment_led", "foreground_priority": "environment", "trigger_focus": "none", "duration_policy": "continuous_loop", "spatial_policy": "mostly_fixed", "trigger_mode": "none", "sections": [{"name": "main", "start_seconds": 0, "end_seconds": 1800, "active_roles": ["bed"]}]},
  "arrangement": {"tracks": [{"source_id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "resource_key": "rain_soft", "role": "bed", "start_seconds": 0, "end_seconds": 1800, "loop": true, "default_volume": 0.3, "fade_in_ms": 500, "fade_out_ms": 500, "keyframes": [{"t": 0, "angle": 0, "radius": 0.8, "interpolation": "smoothstep"}]}]}
}
```

响应 `200`：

```json
{
  "outline": {"name": "檐下听雨", "subtitle": "安静入睡", "description": "睡前雨声", "theme": "rain", "use_case_tags": ["sleep"], "composition_profile": "environment_led", "foreground_priority": "environment", "trigger_focus": "none", "duration_policy": "continuous_loop", "spatial_policy": "mostly_fixed", "trigger_mode": "none", "sections": [{"name": "main", "description": "稳定雨声", "start_seconds": 0, "end_seconds": 1800, "active_roles": ["bed"]}]},
  "arrangement": {"tracks": [{"source_id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "resource_key": "rain_soft", "role": "bed", "start_seconds": 0, "end_seconds": 1800, "loop": true, "default_volume": 0.3, "fade_in_ms": 500, "fade_out_ms": 500, "keyframes": [{"t": 0, "angle": 0, "radius": 0.8, "interpolation": "smoothstep"}]}]},
  "scene": {"name": "檐下听雨", "subtitle": "安静入睡"},
  "composition": {
    "schema": "scene_composition_v2",
    "version": 2,
    "duration_seconds": 1800,
    "source_groups": [{"id": "11111111-1111-4111-8111-111111111111", "name": "轻雨", "symbol_name": null, "layer": "environment", "display_policy": "while_active", "position_keyframes": [{"t": 0, "angle": 0, "radius": 0.8, "interpolation": "smoothstep"}]}],
    "clips": [{"id": "22222222-2222-4222-8222-222222222222", "source_group_id": "11111111-1111-4111-8111-111111111111", "asset_id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "resource_key": "rain_soft", "start_seconds": 0, "end_seconds": 1800, "source_offset_seconds": 0, "playback_mode": "loop", "crossfade_ms": 500, "fade_in_ms": 500, "fade_out_ms": 500}]
  },
  "validation_warnings": []
}
```

服务端会根据编排补齐稳定的 source group、clip 和资源绑定；上例是一个可通过 `scene_composition_v2` 校验的最小非空响应，实际生成可能包含更多条目。

## 4. 一次调用生成完整场景

### `POST /v1/ai/scene-assist/generate`

请求与 `outline` 相同，不需要客户端提供 `outline` 或 `arrangement`：

```json
{
  "selected_sources": [{"source_id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "resource_key": "rain_soft", "name": "轻雨", "description": "柔和雨声", "layer": "environment", "loop": true, "duration_seconds": 30, "default_volume": 0.3, "angle": 0, "radius": 0.8}],
  "options": {"scene_intent": "睡前放松", "duration_seconds": 1800, "language": "zh-CN", "constraints": []}
}
```

响应结构与 `compile` 相同：`outline`、`arrangement`、`scene`、`composition`、`validation_warnings`。服务端按 outline → arrangement → compile 顺序执行。

## 5. 调整已有场景

### `POST /v1/ai/scene-assist/adjust`

请求：

```json
{
  "selected_sources": [{"source_id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "resource_key": "rain_soft", "name": "轻雨", "description": "柔和雨声", "layer": "environment", "loop": true, "duration_seconds": 30, "default_volume": 0.3, "angle": 0, "radius": 0.8}],
  "scene": {"name": "檐下听雨", "composition": {"schema": "scene_composition_v2", "version": 2, "duration_seconds": 1800, "source_groups": [{"id": "11111111-1111-4111-8111-111111111111", "name": "轻雨", "symbol_name": null, "layer": "environment", "display_policy": "while_active", "position_keyframes": [{"t": 0, "angle": 0, "radius": 0.8, "interpolation": "smoothstep"}]}], "clips": [{"id": "22222222-2222-4222-8222-222222222222", "source_group_id": "11111111-1111-4111-8111-111111111111", "asset_id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "resource_key": "rain_soft", "start_seconds": 0, "end_seconds": 1800, "source_offset_seconds": 0, "playback_mode": "loop", "crossfade_ms": 500, "fade_in_ms": 500, "fade_out_ms": 500}]}},
  "instruction": "把雨声降低一些，保持所有声源不变",
  "options": {"duration_seconds": 1800, "language": "zh-CN"}
}
```

响应 `200`：

```json
{
  "scene": {"name": "檐下听雨（柔和）"},
  "composition": {"schema": "scene_composition_v2", "version": 2, "duration_seconds": 1800, "source_groups": [{"id": "11111111-1111-4111-8111-111111111111", "name": "轻雨", "symbol_name": null, "layer": "environment", "display_policy": "while_active", "position_keyframes": [{"t": 0, "angle": 0, "radius": 0.8, "interpolation": "smoothstep"}]}], "clips": [{"id": "22222222-2222-4222-8222-222222222222", "source_group_id": "11111111-1111-4111-8111-111111111111", "asset_id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "resource_key": "rain_soft", "start_seconds": 0, "end_seconds": 1800, "source_offset_seconds": 0, "playback_mode": "loop", "crossfade_ms": 500, "fade_in_ms": 500, "fade_out_ms": 500}]},
  "change_summary": ["降低雨声默认音量"],
  "validation_warnings": []
}
```

调整时，服务端会检查既有源引用和 group/clip 绑定没有被模型意外删除或换绑。

## 将结果写入个人场景草稿

AI 接口不保存结果。客户端在预览、资源 QC、授权检查和移动端试听通过后，调用：

```http
PUT /v1/users/me/scenes/{scene_id}/draft
Authorization: Bearer <access_token>
Content-Type: application/json
```

```json
{
  "name": "檐下听雨",
  "sources": [{"assetId": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "resourceKey": "rain_soft"}],
  "draft_composition": {
    "schema": "scene_composition_v2",
    "version": 2,
    "duration_seconds": 1800,
    "source_groups": [{"id": "11111111-1111-4111-8111-111111111111", "name": "轻雨", "symbol_name": null, "layer": "environment", "display_policy": "while_active", "position_keyframes": [{"t": 0, "angle": 0, "radius": 0.8, "interpolation": "smoothstep"}]}],
    "clips": [{"id": "22222222-2222-4222-8222-222222222222", "source_group_id": "11111111-1111-4111-8111-111111111111", "asset_id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "resource_key": "rain_soft", "start_seconds": 0, "end_seconds": 1800, "source_offset_seconds": 0, "playback_mode": "loop", "crossfade_ms": 500, "fade_in_ms": 500, "fade_out_ms": 500}]
  }
}
```

这一步只更新草稿，不发布正式版本。正式保存仍需用户明确操作 `POST /v1/users/me/scenes/{scene_id}/save`，并经过已有的 composition 校验。

## 稳定错误

服务端最多进行一次 repair retry，且仅针对模型已经返回、但未通过 JSON 解析、schema 或 composition 校验的结果。DeepSeek 的 HTTP、传输或响应格式错误会直接作为 `deepseek_provider_error` 暴露，不会被改写成 repair 请求；传输层重试次数由 `DW_DEEPSEEK_MAX_RETRIES` 单独控制。

所有错误都使用 FastAPI 的 `detail` 字段，但只有 AI 路由自身产生的 503/502 错误保证稳定的 `detail.code` 与 `detail.message`。鉴权和请求校验沿用应用现有的 FastAPI 行为：

| HTTP | 当前 `detail` 形状 | 客户端处理 |
|---:|---|---|
| 401 | 当前鉴权依赖返回的字符串 `detail` | 认证失败；刷新登录态或要求登录 |
| 422 | FastAPI/Pydantic 的验证错误列表 `detail` | 按字段错误提示并修正请求 |
| 503 | `{ "code": "deepseek_configuration_error", "message": "DeepSeek API key is not configured" }` | 不重试；联系部署方配置密钥 |
| 502 | `{ "code": "deepseek_provider_error", "message": "DeepSeek provider request failed" }` | 可提示稍后重试，并保留当前草稿 |
| 502 | `{ "code": "scene_assist_generation_error", "message": "Scene generation failed validation" }` | 保留用户输入；允许重新生成或手动编辑 |

只有 AI 专用 503/502 行的 `code` 是客户端分支判断依据；`message` 供日志和用户提示使用，不应被当作稳定枚举。401/422 的 `detail` 形状由现有鉴权依赖和 FastAPI/Pydantic 处理。

## 密钥与部署

- 本地开发：将密钥写入 `server/.env` 的 `DW_DEEPSEEK_API_KEY`，不要提交该文件。
- 部署环境：使用部署平台的 Secret/环境变量，键名必须是 `DW_DEEPSEEK_API_KEY`。
- `server/.env.example` 只保留空值示例。默认 provider URL、模型和超时也在该文件中声明。
- 前端永远不应读取或打包 DeepSeek 密钥；所有模型请求必须经过后端。

## 草稿与发布边界

`scene_composition_v2` 输出只能视为 draft。通过 API schema 校验不代表素材可以上线。正式使用前必须完成：

1. 资产 QC：文件可读、时长/格式/响度和资源映射符合产品要求。
2. License 检查：每个声音资产都有允许当前发布范围的来源凭证和授权状态。
3. 移动端试听：在目标 iOS 播放链路验证循环、淡入淡出、空间位置、长时稳定性和无声/爆音问题。

任一检查未通过，都只能留在编辑器草稿中。AI 的 `validation_warnings` 也必须展示或记录，不能当作已发布质量证明。
