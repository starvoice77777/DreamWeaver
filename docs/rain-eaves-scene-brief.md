# 檐下听雨场景（sc_rain_v1 orchestration v9）

> 来源：素材包 `sc_rain_v1/orchestration_v9`（归档于 `docs/scenes/sc_rain/packages/sc_rain_v1/`）
>
> 工程：`rain_eaves_timeline_v9.json`（iOS Mock + `server/app/fixtures/`）、`MockDataService.rainEavesScene`、`seed_catalog`

| 项 | 内容 |
|----|------|
| 轨 | A01 `rain_soft`、A02 `rain_parasol`、A03 `rain_bamboo_leaf`、A04 `wind_gust`（trigger oneshot） |
| 时间线 | runtime version **11**；`phrases: []`；36 个位置关键帧由统一渲染器连续插值 |
| 片段 | 6 个 clip；A03 两段共用一个竹叶雨 SourceGroup；A04 两次 oneshot 共用一个阵风 SourceGroup |
| 母带 | 4 个 WAV 与 v8 完全相同，哈希未变 |
| 官方预设 | 0–39 秒竹叶雨单声源开场；39 秒后三层雨景；稳态主次只由 radius 决定 |
| 映射说明 | `packages/sc_rain_v1/INGEST.md` |
