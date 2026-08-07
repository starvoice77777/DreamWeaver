# scene_composition_v2 契约

状态：已实现；`v1` 继续兼容读取，新的创建场景保存为 `v2`。

## 目标

`v2` 将圆盘声源身份与时间轴音频片段分开：

- `source_groups`：圆盘上可见、可拖动的声源；负责共享空间位置与半径增益。
- `clips`：时间轴上可单独增删、移动、循环和校准的音频片段。
- 多个 `clips` 可以引用同一个 `source_group_id`。洗头陪伴的 20 句人声因此是 20 个 clip、1 个圆盘声源。

## 文档结构

```json
{
  "schema": "scene_composition_v2",
  "version": 1,
  "duration_seconds": 620,
  "source_groups": [
    {
      "id": "00000000-0000-4000-8000-000000000001",
      "name": "轻声陪伴",
      "symbol_name": "quote.bubble.fill",
      "layer": "voice",
      "display_policy": "always_in_window",
      "position_keyframes": [
        {
          "t": 0,
          "angle": 0,
          "radius": 0.38,
          "interpolation": "linear"
        }
      ]
    }
  ],
  "clips": [
    {
      "id": "00000000-0000-4000-8000-000000000002",
      "source_group_id": "00000000-0000-4000-8000-000000000001",
      "asset_id": null,
      "resource_key": "voice_phrase_01",
      "start_seconds": 3,
      "end_seconds": 7.1,
      "source_offset_seconds": 0,
      "playback_mode": "oneshot",
      "crossfade_ms": 0,
      "fade_in_ms": 0,
      "fade_out_ms": 0,
      "phrase_id": "00000000-0000-4000-8000-000000000002",
      "text_cue_id": null,
      "mastering_profile_key": "voice_phrase_01"
    }
  ]
}
```

## 枚举与约束

- `interpolation`：`linear`、`smoothstep`、`recorded_linear`。
- `playback_mode`：`oneshot`、`loop`、`bounded_loop`。
- `display_policy`：`always_in_window`、`while_active`、`selected_or_active`。
- `duration_seconds > 0`。
- group、clip ID 各自唯一；每个 `source_group_id` 必须引用已有 group。
- clip 必须位于 `[0, duration_seconds]` 内，且 `end_seconds > start_seconds`。
- `asset_id` 与 `resource_key` 至少存在一个。
- `crossfade_ms` 为非负整数；oneshot 必须为 0；非零值必须小于 clip 时长的一半。播放器还会按实际素材时长做二次上限保护。
- `fade_in_ms`、`fade_out_ms` 为非负整数，且各自不得超过 clip 时长；两者之和不得超过 clip 时长。
- 位置关键帧严格递增，`radius` 位于 `[0, 1]`。

## 兼容与执行边界

- 服务端 `/v1/compositions/validate`、私人场景 draft/save 同时接受 v1、v2，JSON 快照不反向降级。
- v1 在客户端编译为“一条 track 对应一个 SourceGroup 与一个 AudioClip”。
- 官方 timeline 暂不改 endpoint，由 `ScenePlanCompiler` 编译为相同的 `SceneRenderPlan`。
- 创建预览和播放页只执行 `SceneRenderPlan`；不再直接把 cue 或编辑器行解释为播放器节点。
- 半径增益只施加在 SourceGroup mixer 一次。素材响度补偿、clip 淡入淡出、duck 和循环 A/B crossfade 属于内部处理，不生成额外圆盘图标。
