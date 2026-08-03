# 场景时间线契约（Stage 6 PR1）

版本：`timeline-contract-v1`  
日期：2026-08-02  
范围：服务器下发版本化 Cue/Phrase 文档；客户端调度执行。服务器不参与实时混音。

## 1. 端点

| 方法 | 路径 | 鉴权 | 说明 |
|------|------|------|------|
| GET | `/v1/scenes/{sceneId}/timeline` | 否 | 官方场景时间线；场景不存在 → 404；无文档时返回空 cues 的合法壳 |
| PUT | `/v1/users/me/scenes/{id}/draft` | Bearer | 可写 `draft_timeline`（与 `sources` 一并） |
| POST | `/v1/users/me/scenes/{id}/save` | Bearer | 将 `draft_timeline` 快照到 `saved_timeline` |
| POST | `/v1/scenes/{id}/copy` | Bearer | 复制官方 timeline 到个人 `draft_timeline` |

## 2. 文档形状（JSON）

```json
{
  "scene_id": "a1111111-1111-4111-8111-111111111101",
  "version": 1,
  "automation_mode": "official_auto",
  "duration_hint_seconds": 2700,
  "override_policy": "per_source_manual_exit",
  "manual_override_track_ids": [],
  "phrases": [
    {
      "id": "f6666666-6666-4666-8666-666666666601",
      "text": "睡吧，我在。",
      "review_status": "approved",
      "voice_binding": {
        "kind": "official_resource",
        "resource_key": "voice_phrase_mom",
        "track_id": "e5555555-5555-4555-8555-555555555503",
        "track_layer": "voice"
      }
    }
  ],
  "cues": [
    {
      "id": "f6666666-6666-4666-8666-666666666611",
      "at_seconds": 6.0,
      "progress": null,
      "repeat_every_seconds": null,
      "until_seconds": null,
      "actions": [
        {
          "type": "play_phrase",
          "phrase_id": "f6666666-6666-4666-8666-666666666601",
          "track_id": "e5555555-5555-4555-8555-555555555503"
        }
      ]
    }
  ]
}
```

### 字段说明

| 字段 | 含义 |
|------|------|
| `version` | 文档修订号（整数，从 1 起） |
| `automation_mode` | `official_auto` \| `manual` |
| `duration_hint_seconds` | 与场景推荐时长对齐 |
| `override_policy` | 固定 `per_source_manual_exit`：用户拖过的轨退出自动编排 |
| `manual_override_track_ids` | 已退出自动编排的 `track_id` 列表（私人草稿/保存可携带；官方种子默认为 `[]`） |
| `phrases[]` | 短句与声音绑定 |
| `cues[]` | 触发点与动作列表 |

### Cue 触发

- `at_seconds`：场景开始后的墙钟秒（首期主时钟，对应 `clock = elapsed`）
- `progress`：0…1 会话/文本进度（可选；与 `at_seconds` 互斥）
- `repeat_every_seconds` + `until_seconds`：从 `at_seconds` 起按间隔重复，直到 `until_seconds`

### CueAction `type`（首期）

| type | 用途 |
|------|------|
| `play_phrase` | 播放 `phrase_id`（通常 oneshot 人声） |
| `play_oneshot` | 从头播放指定轨一次（动作/触感触发音；不循环） |
| `play` / `pause` | 启停轨 |
| `fade_in` / `fade_out` | 淡入淡出（`fade_ms`） |
| `set_volume` | 目标音量（`volume` + 可选 `fade_ms`） |
| `set_position` | 空间位置（`angle` / `radius`；客户端可映射为 `move`） |
| `enable` / `disable` | 启用/禁用轨 |
| `replace_source` | 换源（`resource_key` / `asset_id`） |

未知 `type`：旧客户端应忽略该 action，不中断调度。

### VoiceBinding `kind`

- `official_resource`：Bundle / 官方存储键（`resource_key`）
- `system`：系统合成（预留）
- `authorized_asset`：用户授权种子（`asset_id`）

## 3. 用户覆盖规则

1. 用户手动调整某声源（拖动/改音量等）后，客户端将该 `track_id` 加入 `manual_override_track_ids`。
2. 调度器跳过 **该轨** 相关的后续自动化 action；其余轨继续执行。
3. 显式保存时，`saved_timeline` 应携带当时的 `manual_override_track_ids` 与 cues 快照。

执行调度（替换本地固定 6s / 28s Timer）属于 **阶段 6 PR2**（`SceneTimelineScheduler` + `LocalPlaybackService`）。

## 4. 官方种子

- 「洗头陪伴」：脚本 **v4**（约 620s），见 `docs/hair-care-scene-brief.md` 与 `hair_care_timeline_v4.json`；多句 `play_phrase` + 分层 `play_oneshot` / `set_volume` / `set_position`（人声母带未齐前用 `voice_phrase_mom` 占位）。
- 「檐下听雨」：`rain_eaves_timeline_v5`（约 620s，`phrases: []`；对齐素材包 sc_rain_v1；远雨 / 近雨 / 竹叶雨 / 远风分层 cue + `set_position`）。
- 其他含 voice 轨的场景：最小首句 + 28s 重复。
- 无 voice 轨：空 `phrases` / `cues`，仍返回合法文档壳。

## 5. 私人场景快照

| 列 / 字段 | 说明 |
|-----------|------|
| `draft_timeline` | 草稿中的时间线 JSON（与 `SceneTimelineOut` 同形，可无 `scene_id` 或填私人 id） |
| `saved_timeline` | 用户点保存后的正式快照；与 `saved_sources` 同事务递增 `saved_version` |

复制官方场景时：把官方 timeline 拷入 `draft_timeline`（`automation_mode` 可保持 `official_auto`，`manual_override_track_ids` 置空）。
