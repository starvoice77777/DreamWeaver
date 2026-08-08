# sc_rain_v1 工程接入说明

来源：素材交付包 `sc_rain_v1`（2026-08，当前编排 **v9**）

仓库路径：本目录  
状态：`demo_ready=true`，`release_ready=false`（母带 `qc_pending`，待外放/耳机/接缝验收）

## 仓库映射

| 包内 | 工程 |
|------|------|
| `audio/master/*.wav` | Bundle 短键 `rain_soft` / `rain_parasol` / `rain_bamboo_leaf` / **`wind_gust`**（A01–A03 母带哈希与 v6 相同；A04 新 oneshot） |
| `orchestration_v9/*.csv` | 当前唯一编排源；工程生成 `timeline-contract-v1` → `rain_eaves_timeline_v9.json` |
| `orchestration_v9/position_keyframes.csv` | 展开为 `set_position` cue；统一渲染器按 `linear` 连续插值 |
| `scene/timeline.json` | 保留为 v8 历史输入，仅用于追溯，不再生成当前 fixture |
| 包内 track UUID | **保留** DemoIDs（`e555…501/502/510/512`），不改 catalog 主键 |

### track_id 对照

| 包 code | resource_key | 工程 track_id |
|---------|--------------|---------------|
| A01 | `rain_soft` | `e5555555-5555-4555-8555-555555555510` |
| A02 | `rain_parasol` | `e5555555-5555-4555-8555-555555555501` |
| A03 | `rain_bamboo_leaf` | `e5555555-5555-4555-8555-555555555512` |
| A04 | `wind_gust` | `…502`；`layer=trigger`；`play_oneshot` @ 188s / 458s |

### v9 编排相对 v8

- 0–39 秒仅播放 A03 竹叶雨，完成近到远、左到右、向边缘退出的连续空间过渡。
- A01/A02 在 39 秒进入；A03 在 39.2 秒作为同一逻辑声源的第二个 clip 重新进入。
- A04 仍为同组两次 `wind_gust` oneshot（188 秒、458 秒），没有增加事件或素材。
- 稳态层级只使用 radius；`set_envelope` 仅承载 clip 淡入淡出。
- 再生 fixture：`python server/scripts/build_rain_eaves_timeline_v9.py`

未入库：`audio/demo/`、`audio/alternatives/`（体积大，仅 WeChat 原包保留；验收可用原包）。

## 升级后动作

1. `alembic` 无需新迁移；启动 API 后走 `ensure_official_timelines`（rainEaves runtime version < 11 会升级）。
2. 或调用非 production `POST /v1/admin/reseed-catalog`。
3. iOS：确认 Bundle 含 `rain_eaves_timeline_v9.json` 与原有 4 个雨景 WAV；冷启动或切远端后端后重开。
