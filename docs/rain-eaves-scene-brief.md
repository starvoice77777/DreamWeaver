# 檐下听雨场景（sc_rain_v1 → timeline v5）

> 来源：素材包 `sc_rain_v1`（归档于 `docs/scenes/sc_rain/packages/sc_rain_v1/`）+ 《檐下听雨_场景时间戳与素材清单_v5》  
> 工程：`rain_eaves_timeline_v5.json`（iOS Mock + `server/app/fixtures/`）、`MockDataService.rainEavesScene`、`seed_catalog`  
> 映射说明：`packages/sc_rain_v1/INGEST.md`

## 已实现

| 项 | 说明 |
|----|------|
| 总时长 | `duration_hint_seconds = 620`（约 10:20） |
| 轨 | A01 `rain_soft`、A02 `rain_parasol`、A03 `rain_bamboo_leaf`、A04 `wind_realistic` |
| 时间线 | version **5**；`phrases: []`；包内 cue 映射为 DemoIDs + `set_position`（A04 两段共用风轨） |
| 母带 | Bundle WAV = 包内 `audio/master` v02 |
| 模板 | 规范 §6-B 无文本环境型（无人声） |
| 素材状态 | 母带仍 **`qc_pending`** / `demo_ready`；`release_ready=false` |

## 已知缺口

- `room_wood_tone` 未收集
- 外放 / 耳机 / ≥2 分钟循环接缝验收未勾完
- 旧 DB：`rainEaves` timeline `version < 5` 时由 `ensure_official_timelines` 升级；轨默认位置/图层需 `reseed-catalog` 或清库

## 共享文件

- `DemoIDs`（轨 UUID 不变）
- `MockDataService` / `seed_catalog` / Bundle 音频
- 未改 `AppState` / `NowView` / 圆盘手势逻辑
