# sc_rain_v1｜檐下听雨场景素材包

- 场景类型：无文本、无人声、低变化环境预设
- 目标时长：620 秒（10:20）
- 包版本：1.3.0；时间线版本：v8（A04 合并为一个轨道、两个单次播放事件）
- 输出策略：手机外放优先，耳机可获得更明确的空间层次
- 当前状态：`demo_ready=true`，`release_ready=false`
- 原因：四条推荐母带均已完成指标处理，但仍为 `qc_pending`；A04 第三方来源授权待核验，需完成实机试听和授权归档后才能升为 `master`

## 使用顺序

1. 后端先读取 `scene/scene_manifest.json`。
2. 使用 `scene/timeline.json` 作为执行真相源，`scene/tracks.csv` 供人工核对和导入。
3. 时间线引用的文件只来自 `audio/master/`；`alternatives/` 仅供 A/B 试听，`demo/` 仅供复赛或长时试听。
4. 产品与素材人员阅读 `docs/檐下听雨_场景时间戳与素材清单_v8.docx`；v5–v7 仅保留为历史版本。
5. 按 `qc/scene_acceptance.md` 完成手机外放、耳机和连续循环验收。

## 场景层次

- A01 `rain_soft`：0:00–10:20，持续远雨底层。
- A02 `rain_parasol`：0:30–9:20，近处檐雨主环境。
- A03 `rain_bamboo_leaf`：3:40–8:50，低音量竹叶雨细节。
- A04 `wind_gust`：只建立一个轨道和一个 `track_id`；3:08、7:38 通过两个 `playback_events` 分别执行一次 3.709 秒远处阵风，并使用同一轨道上的两组位置关键帧。

本包不包含人声、文本、音乐、雷声、鸟叫或突发 ASMR 触发音。
