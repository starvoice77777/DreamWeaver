# 场景创作 Composition 契约（scene_composition_v1）

版本：`scene-composition-v1`  
日期：2026-08-03  
范围：用户「创建」模式产出的音频轨 + 位置关键帧文档；与官方 cue/phrase 时间线**并存**。  
产品依据：PRD v1.3（音频轨时间轴场景）；取消语音克隆；取消路径禁穿中心限制。

## 1. 与官方 timeline 的关系

| 文档 | 用途 | 执行方 |
|------|------|--------|
| `timeline-contract-v1`（cue/phrase） | 官方预设自动编排 | `SceneTimelineScheduler` |
| `scene_composition_v1`（本文件） | 用户创建的轨轴 + 关键帧 | 客户端关键帧插值播放器（后续） |

私人场景可同时持有：

- `draft_timeline` / `saved_timeline`（从官方复制时的 cue 快照）
- `draft_composition` / `saved_composition`（创建编辑结果）

播放优先级由客户端决定（建议：若存在非空 composition 则按 composition 播；否则走 timeline）。

## 2. 端点

| 方法 | 路径 | 鉴权 | 说明 |
|------|------|------|------|
| PUT | `/v1/users/me/scenes/{id}/draft` | Bearer | 可写 `draft_composition`（与 sources / draft_timeline 一并） |
| POST | `/v1/users/me/scenes/{id}/save` | Bearer | 将 draft 快照到 `saved_composition`（若 draft 含 composition 则先校验） |
| GET | `/v1/users/me/scenes/{id}` | Bearer | 详情含 draft/saved composition |
| POST | `/v1/compositions/validate` | Bearer | 仅校验，不落库；返回规范化文档或错误定位 |

从官方 `POST /v1/scenes/{id}/copy`：继续复制 timeline；`draft_composition` 默认为 `null`（由前端从 mix 生成静态关键帧轨，属客户端）。

## 3. 文档形状

```json
{
  "schema": "scene_composition_v1",
  "version": 1,
  "duration_seconds": 120.0,
  "tracks": [
    {
      "id": "e5555555-5555-4555-8555-555555555510",
      "asset_id": null,
      "resource_key": "rain_soft",
      "layer": "ambience",
      "loop": true,
      "start_seconds": 0.0,
      "end_seconds": 120.0,
      "source_duration_seconds": 30.0,
      "keyframes": [
        { "t": 0.0, "angle": 0.5, "radius": 0.8, "volume": 0.4 },
        { "t": 60.0, "angle": 2.0, "radius": 0.35, "volume": 0.5 }
      ]
    }
  ]
}
```

### 字段

| 字段 | 含义 |
|------|------|
| `schema` | 固定 `scene_composition_v1` |
| `version` | 文档修订号（整数 ≥ 1） |
| `duration_seconds` | 场景时长；校验时可写回为 `max(track.end_seconds)` |
| `tracks[].id` | 轨 UUID |
| `asset_id` / `resource_key` | 至少其一非空（用户资产或官方短键） |
| `layer` | 与现有声源层一致（如 `ambience` / `environment` / `voice` / `trigger`） |
| `loop` | 是否在 `[start,end]` 内循环 |
| `start_seconds` / `end_seconds` | 轨在场景轴上的起止；须 `end > start` |
| `source_duration_seconds` | 素材原始时长（可选，UI 展示） |
| `keyframes[].t` | 相对场景开始的秒；落在 `[start_seconds, end_seconds]` |
| `angle` / `radius` / `volume` | 空间与音量；`radius`/`volume` ∈ `[0,1]` |

## 4. 校验规则（服务端）

1. `schema == scene_composition_v1`；`version` 为正整数。
2. `tracks` 为非空数组（保存时）；validate 接口允许空 tracks 仅用于草稿探测时返回 422 说明。
3. 每轨：`id` 合法 UUID；`end_seconds > start_seconds`；`start_seconds ≥ 0`。
4. `asset_id` 与 `resource_key` 不能同时为空。
5. 关键帧：至少 1 个；按 `t` **严格升序**（相等则 400）；每个 `t` ∈ `[start, end]`。
6. `radius`、`volume` ∈ `[0, 1]`；`angle` 为有限浮点。
7. 校验成功后写回 `duration_seconds = max(end_seconds)`。
8. **不做**路径禁区 / 中心穿越几何校验（产品已取消）。

错误体建议：

```json
{
  "detail": {
    "message": "Keyframe t out of track range",
    "track_id": "…",
    "keyframe_index": 2
  }
}
```

## 5. 关键帧插值（客户端；服务端不 densify）

相邻帧 `i` → `i+1`，时间 `t`：

- `u = (t - t_i) / (t_{i+1} - t_i)`
- `radius = lerp(r_i, r_{i+1}, u)`
- `volume = lerp(v_i, v_{i+1}, u)`
- `angle = angle_i + shortest_delta(angle_i, angle_{i+1}) * u`

允许路径经过圆心（`radius → 0`）。结果映射现有 `SoundSource.position`。建议 30–60 Hz 采样，**不写回库**。

## 6. 客户端约定（一期 UX，已与前端对齐）

| 项 | 约定 |
|----|------|
| 入口 | 底部中间 **「创建」Tab**（独立一级，不嵌在「此刻」） |
| 关键帧 | 轨上可点选多帧；时间游标处可插入；画布拖动只改**当前选中关键帧** |
| 选中态 / 游标 | 纯客户端状态，**不**进入 composition JSON |
| Seed / 克隆 | 产品路径隐藏；勿把「创建」做成声样克隆入口 |

## 7. 语音克隆

不提供用户/亲友声样克隆。人声仅官方 `resource_key` 或预留系统朗读。Seed / VoiceAuthorization API **deprecated**，仅开发遗留。
