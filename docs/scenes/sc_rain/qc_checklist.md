# 檐下听雨 QC 清单（工程接入 sc_rain_v1 / orchestration v9）

本版试听验收：`packages/sc_rain_v1/orchestration_v9/listen_notes.md`

工程映射：`packages/sc_rain_v1/INGEST.md`

## 工程接入

- [x] v9 CSV 通过编排约束校验；4 个母带 SHA-256 与 v8 一致
- [x] 工程 fixture `rain_eaves_timeline_v9.json` 通过 `timeline-contract-v1`（本地/服务器一致）
- [x] 36 个 `position_keyframes` 已展开为 `set_position`，播放端连续插值
- [x] A03 两段 clip 共用一个 SourceGroup，39.0–39.2 秒静音间隙不显示声源
- [x] A04 `play_oneshot` ×2（188s / 458s）

## 待人工试听

- [ ] 0–39 秒仅竹叶雨；18–39 秒连续远近/左右/退出轨迹符合 v9 试听表
- [ ] 39–42 秒三层建立自然，A03 退出/重新进入无爆点
- [ ] A01–A03 循环接缝、片段淡入淡出与结尾退场无咔哒或硬停
- [ ] `wind_gust` 两处 oneshot（约 3:08、7:38）音量合适、空间扫过自然
- [ ] 檐下雨 > 远雨 > 竹叶雨的 radius 层级在耳机与外放均成立

## 人工试听（v9 空间编排）

按 `orchestration_v9/listen_notes.md` 完成 620 秒整段验收；正式上架前补 license 归档。
