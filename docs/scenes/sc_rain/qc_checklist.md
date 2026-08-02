# 檐下听雨 QC 清单（v2 / 协同表 v4）

## 机器门禁

- [ ] `timeline.json` 通过 `timeline-contract-v1` schema
- [ ] 全部 cue `track_id` ∈ `tracks.csv`
- [ ] `angle` 为弧度 ∈ [-π, π]；`volume` / `radius` / `fade_ms` 合法
- [x] `phrases: []`（无文本环境型）
- [ ] 正式上架前：`asset_status=master` 且 `license_status=approved`（当前均为 `qc_pending`）

## 循环与 crossfade

- [ ] `rain_soft` / `rain_parasol` / `rain_bamboo_leaf` 各循环 ≥2 分钟听接点
- [ ] 若接点明显：确认客户端引擎 crossfade，或更新母带闭环
- [ ] `wind_realistic` 短段进出无爆点

## 人工试听

- [ ] 手机外放：远雨垫底可辨，近雨不刺耳，竹叶层低于主雨
- [ ] 耳机：无快速绕头；风声两段（约 3:00、7:30）轻柔
- [ ] 结尾 9:20–10:20 可预期淡出，无硬停
- [ ] 任意 90 秒窗口无明显「事件感」突变（除已脚本化的风声短段）

## 缺口

- `room_wood_tone` 未交付（P1 planned）
- 许可证尚未 `approved`
