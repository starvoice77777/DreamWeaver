# 檐下听雨场景（sc_rain_v1 → timeline v8）

> 来源：素材包 `sc_rain_v1`（归档于 `docs/scenes/sc_rain/packages/sc_rain_v1/`）  
> 工程：`rain_eaves_timeline_v8.json`（iOS Mock + `server/app/fixtures/`）、`MockDataService.rainEavesScene`、`seed_catalog`

| 项 | 内容 |
|----|------|
| 轨 | A01 `rain_soft`、A02 `rain_parasol`、A03 `rain_bamboo_leaf`、A04 `wind_gust`（trigger oneshot） |
| 时间线 | version **8**；`phrases: []`；A04 用 `play_oneshot`；`position_keyframes` 展开为离散 `set_position` |
| 母带 | A01–A03 = 包内 v02（与 v6 哈希相同）；A04 新 `wind_gust` v03 oneshot |
| 官方预设 | 「细雨慢听」对齐上述四轨（阵风为 trigger，默认音量 0.20） |
| 映射说明 | `packages/sc_rain_v1/INGEST.md` |
