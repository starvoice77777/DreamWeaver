# sc_rain_v1 工程接入说明

来源：素材交付包 `sc_rain_v1`（2026-08）  
仓库路径：本目录  
状态：`demo_ready=true`，`release_ready=false`（母带 `qc_pending`，待外放/耳机/接缝验收）

## 仓库映射

| 包内 | 工程 |
|------|------|
| `audio/master/*.wav` | Bundle 短键 `rain_soft` / `rain_parasol` / `rain_bamboo_leaf` / `wind_realistic` |
| `scene/timeline.json`（内容包 v5） | 映射为 `timeline-contract-v1` → `rain_eaves_timeline_v5.json` |
| 包内 track UUID | **保留** DemoIDs（`e555…501/502/510/512`），不改 catalog 主键 |

### track_id 对照

| 包 code | resource_key | 工程 track_id |
|---------|--------------|---------------|
| A01 | `rain_soft` | `e5555555-5555-4555-8555-555555555510` |
| A02 | `rain_parasol` | `e5555555-5555-4555-8555-555555555501` |
| A03 | `rain_bamboo_leaf` | `e5555555-5555-4555-8555-555555555512` |
| A04a / A04b | `wind_realistic` | 同一轨 `…502`；两次起风用 `set_position` 换位 |

未入库：`audio/demo/`、`audio/alternatives/`（体积大，仅 WeChat 原包保留；验收可用原包）。

## 升级后动作

1. `alembic` 无需新迁移；启动 API 后走 `ensure_official_timelines`（rainEaves version < 5 会升级）。
2. 或调用非 production `POST /v1/admin/reseed-catalog`。
3. iOS：确认 Bundle 含 `rain_eaves_timeline_v5.json` 与更新后的 WAV。
