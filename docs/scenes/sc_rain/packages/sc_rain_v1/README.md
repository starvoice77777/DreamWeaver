# sc_rain_v1｜檐下听雨场景素材包

- 场景类型：无文本、无人声、低变化环境预设
- 目标时长：620 秒（10:20）
- 包版本：1.4.0；当前编排版本：v9（母带不变，SourceGroup/AudioClip 分离）
- 输出策略：手机外放优先，耳机可获得更明确的空间层次
- 当前状态：`demo_ready=true`，`release_ready=false`
- 原因：四条推荐母带均已完成指标处理，但仍为 `qc_pending`；A04 第三方来源授权待核验，需完成实机试听和授权归档后才能升为 `master`

## 使用顺序

1. 后端先读取 `scene/scene_manifest.json`。
2. 使用 `orchestration_v9/*.csv` 作为当前编排真相源，并由 `server/scripts/build_rain_eaves_timeline_v9.py` 生成双端 fixture。
3. `scene/timeline.json` 与 `scene/tracks.csv` 是 v8 历史输入，只用于变更对比，不再驱动当前预设。
4. 时间线引用的文件只来自 `audio/master/`；`alternatives/` 仅供 A/B 试听，`demo/` 仅供复赛或长时试听。
5. 产品与素材人员以 `orchestration_v9/README.md`、CSV 和 `listen_notes.md` 为准；旧 Word 文档仅保留为历史版本。
6. 按 `orchestration_v9/listen_notes.md` 完成手机外放、耳机和连续循环验收。

## 场景层次

- A03 `rain_bamboo_leaf`：0:00–0:39 单声源空间开场；0:39.2–8:50 以同一逻辑声源重新进入为轻细节。
- A01 `rain_soft`：0:39–10:20，远雨承托并在最后 60 秒退远淡出。
- A02 `rain_parasol`：0:39–9:20，近处檐雨主环境。
- A04 `wind_gust`：只建立一个轨道和一个 `track_id`；3:08、7:38 通过两个 `playback_events` 分别执行一次 3.709 秒远处阵风，并使用同一轨道上的两组位置关键帧。

所有稳态层级通过 position keyframe 的 `radius` 表达；`fade_in_ms` / `fade_out_ms` 只用于片段边界过渡。

本包不包含人声、文本、音乐、雷声、鸟叫或突发 ASMR 触发音。
