# 檐下听雨 QC 清单（工程接入 sc_rain_v1 / timeline v5）

包内验收原文：`packages/sc_rain_v1/qc/scene_acceptance.md`  
工程映射：`packages/sc_rain_v1/INGEST.md`

## 机器门禁

- [x] 内容包 `package_validation.json` passed（交付方）
- [x] 工程 fixture `rain_eaves_timeline_v5.json` 通过 `timeline-contract-v1`（UUID cue / DemoIDs）
- [x] `phrases: []`（无文本环境型）
- [ ] 正式上架前：`asset_status=master` 且凭证归档（当前母带仍 `qc_pending`，演示 license 表为 approved）

## 循环与 crossfade

- [ ] `rain_soft` / `rain_parasol` / `rain_bamboo_leaf` 各循环 ≥2 分钟听接点
- [ ] 引擎按轨 `crossfade_ms`（1.0s / 1.2s / 0.8s / 1.0s）处理短循环
- [ ] `wind_realistic` 两段（3:00、7:30）进出无爆点

## 人工试听

- [ ] 手机外放：远雨垫底可辨，近雨不刺耳，竹叶层低于主雨
- [ ] 耳机：无快速绕头；风声两段轻柔、左右层次可辨
- [ ] 结尾 9:20–10:20 可预期淡出，无硬停
- [ ] 整场无音乐、人声、雷声、鸟叫

## 缺口

- `room_wood_tone` 未交付（P1 planned）
- 包内 `audio/demo` / `alternatives` 未入库（体积；验收用原 WeChat 包）
