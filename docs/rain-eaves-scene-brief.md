# 檐下听雨场景（后端交接 v1.2）

现行真相源：`backend_handoff_v1_2/scene_packages/sc_rain_v1/scene/timeline.json`，源版本 v11。
工程使用 `rain_eaves_timeline_v12.json`（iOS Mock 与 `server/app/fixtures/` 内容一致）。
内部修订号升至 12，以替代此前已占用修订号 11 的 orchestration v9 数据。

- 时长 620 秒，无人声；保留原场景与四个声源 UUID。
- 远雨 0 秒进入，檐下雨 30 秒进入，竹叶雨 220 秒进入；阵风在 188/458 秒各播放一次。
- 共 5 个片段、27 个 cue、26 个空间关键帧；位置和素材混音增益独立保留。
- 四个 WAV 复用现有文件，导入器校验其 SHA-256 与新包一致。
- 当前仍为审核资产，未完成正式发布授权和外放/耳机试听。

生成、升级与验证方式见 [接入说明](handoff-audio-import.md) 和 [时间线契约](scene-timeline-contract.md)。
`docs/scenes/sc_rain/packages/sc_rain_v1/orchestration_v9/` 及对应 QC 文档仅保留为历史记录。
