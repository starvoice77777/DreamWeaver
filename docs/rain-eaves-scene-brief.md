# 檐下听雨场景（sc_rain_v1 → timeline v6）

> 来源：素材包 `sc_rain_v1`（归档于 `docs/scenes/sc_rain/packages/sc_rain_v1/`）+ 《檐下听雨_场景时间戳与素材清单_v6》  
> 工程：`rain_eaves_timeline_v6.json`（iOS Mock + `server/app/fixtures/`）、`MockDataService.rainEavesScene`、`seed_catalog`  
> 映射说明：`packages/sc_rain_v1/INGEST.md`

## 已实现

| 项 | 说明 |
|----|------|
| 总时长 | `duration_hint_seconds = 620`（约 10:20） |
| 轨 | A01 `rain_soft`、A02 `rain_parasol`、A03 `rain_bamboo_leaf`、A04 `wind_realistic` |
| 时间线 | version **6**；`phrases: []`；音量 cue 同 v5；`position_keyframes` 展开为离散 `set_position` |
| 母带 | Bundle WAV = 包内 `audio/master` v02（v6 相对 v5 **未改音频**） |
| 模板 | 规范 §6-B 无文本环境型（无人声） |
| 素材状态 | 母带仍 **`qc_pending`** / `demo_ready`；`release_ready=false` |

## 已知缺口

- `room_wood_tone` 未收集
- 母带正式 QC / 凭证归档前不可标 `release_ready`
- 引擎对 `set_position` 为阶跃（无关键帧插值）
