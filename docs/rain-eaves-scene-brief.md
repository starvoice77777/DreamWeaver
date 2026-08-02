# 檐下听雨场景（协同表 v4 → timeline v2）

> 来源：微信素材包 `ziran/processed` + 《自然场景_无文本时间线与素材清单_v4》+ `scene-creation-spec-v1.1`  
> 工程：`rain_eaves_timeline_v2.json`（iOS Mock + `server/app/fixtures/`）、`MockDataService.rainEavesScene`、`seed_catalog`

## 已实现

| 项 | 说明 |
|----|------|
| 总时长 | `duration_hint_seconds = 620`（约 10:20） |
| 轨 | A01 `rain_soft`、A02 `rain_parasol`、A03 `rain_bamboo_leaf`、A04 `wind_realistic` |
| 时间线 | version **2**；`phrases: []`；分层 `enable` / `play` / `set_volume` / `disable` |
| 模板 | 规范 §6-B 无文本环境型（无人声） |
| 素材状态 | 全部 **`qc_pending`**，可本地演示；正式 Bundle 上架前须 QC + 许可证 |

## 已知缺口

- `room_wood_tone` 未收集
- A01–A03 标注 `requires_engine_crossfade=true`
- 旧 DB 若仍是 3 轨旧时间线，需 `version < 2` 自动升级（仅 timeline；轨表需重 seed 或清库）

## 共享文件

- `DemoIDs`（新增竹叶轨 UUID）
- `MockDataService` / `seed_catalog`（对齐轨与短键）
- 未改 `AppState` / `NowView` / 圆盘手势逻辑（仅 palette 短键映射）
