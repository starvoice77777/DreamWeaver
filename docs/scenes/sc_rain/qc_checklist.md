# 檐下听雨 QC 清单（工程接入 sc_rain_v1 / timeline v8）

包内验收原文：`packages/sc_rain_v1/qc/scene_acceptance.md`  
工程映射：`packages/sc_rain_v1/INGEST.md`

## 工程接入

- [x] 工程 fixture `rain_eaves_timeline_v8.json` 通过 `timeline-contract-v1`（UUID cue / DemoIDs）
- [x] Bundle 短键含 `wind_gust.wav`；A01–A03 母带哈希与包内 v02 一致
- [x] v8：`position_keyframes` 已展开为 `set_position`（本地/服务器 fixture 一致）
- [x] A04 `play_oneshot` ×2（188s / 458s）

## 待人工试听

- [ ] A01–A03 进出场与空间运动无爆点、无接缝咔哒
- [ ] `wind_gust` 两处 oneshot（约 3:08、7:38）音量合适、空间扫过自然
- [ ] 官方预设「细雨慢听」稳态混音与时间线自动化不打架

## 人工试听（含 v8 空间编排）

见包内 `qc/` 报告；正式上架前补 license 归档。
