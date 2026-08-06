# 洗头陪伴场景（脚本 v4）实现说明与素材文档评审

> 来源：素材包 `processed_v2` + 《洗头场景_文本与声音时间戳协同表_v4_A01渐弱退出》  
> 工程落地：`hair_care_timeline_v4.json`（iOS Bundle + `server/app/fixtures/`）、`MockDataService.hairCareScene`、`seed_catalog`、播放端 `play_oneshot`

## 1. 已实现内容

| 项 | 说明 |
|----|------|
| 总时长 | `duration_hint_seconds = 620`（约 10:20） |
| 轨清单 | 底噪 `ac_hum` + A01/A02/A03/A04/A05/A07/A10/A11 对应短键；主流程**不用** A08/A09 |
| 时间线 | version **5**：多句 `play_phrase` + 分层 `set_envelope` / `fade_out` / `set_position` / `play_oneshot` |
| 人声 | 表内每句文本已写入 `phrases[].text`；音频暂统一绑 `voice_phrase_mom`（占位） |
| 退出 | A01 渐弱至静音（约 10:12–10:20），与 PDF 一致 |

本地模式读 Bundle 内 `hair_care_timeline_v4.json`；远程模式由 `GET /v1/scenes/{id}/timeline` 返回同一 fixture（已有库若 timeline `version < 4` 会自动升级）。

**已知缺口（产品可接受的原型状态）**

- 正式人声短句母带未交付 → 播放时各句听感相同（占位）。
- 素材均为 **ref**，不宜当官方分发最终母带。
- A01 oneshot / loop 在工程侧合并为同一 `resource_key`；循环段落依赖播放器 loop，未做独立 crossfade 母带。
- 既有 Postgres 若仍挂着旧轨（`hair_wash` / `hair_dryer`），需重建 catalog 或清库后重 seed（timeline 会升到 v4，轨表不会自动改写）。

## 2. PDF / 协同表内容质量评审

### 做得好的地方

- **叙事节奏清晰**：短句 + 长留白、30 秒内最多一句文本，适合睡眠/陪伴场景。
- **分层明确**：环境 / 动作 / 触感 / 人声，并给出相对人声的 dB 区间。
- **时间戳可执行**：多数段落同时给出「人声起止」与「动作声进入/持续/退出」，工程师可直接映射到 cue。
- **资源映射表完整**：Axx → 建议 `resource_key` → 实际母带文件名 → 场景用途；并标明 ref / 未有 / 主流程不用。
- **设备约束写明**：手机外放优先、空间变化要慢，避免实现时做成快速绕头。

### 不足以「完整无歧义建场景」的缺口

| 缺口 | 影响 |
|------|------|
| **人声成品全部「未有」** | 无法验收真实台词听感；只能先占位。 |
| **绝对音量未落到 0–1 / LUFS** | dB 相对人声有用，但仍需工程自行换算为素材响度基准；用户听感由圆盘半径决定。 |
| **空间只有定性描述** | 「右侧偏远约 20%」未给稳定的 `angle`/`radius` 数值表，实现会有主观偏差。 |
| **oneshot vs loop 切换规则偏软** | A01 / A01-L 等需工程猜何时切；最好直接给 cue 动作类型。 |
| **fade_ms / ducking 未结构化** | 「人声出现时其他层暂降约 4 dB」未写成可解析事件。 |
| **验收标准偏主观** | 「试听验收」段落对工程 CI / 自动化帮助有限。 |
| **PDF 非机器可读** | 每次改表需人工转录；易与 JSON 时间线漂移。 |

**结论**：作为**创意 + 参考实现说明**质量良好（约 7/10）；作为**唯一工程交付物**不够。当前足以搭出可演示的官方时间线原型，但不足以在无程序员补全假设的情况下「一次对齐、可回归验收」的完整场景构建。

## 3. 建议的文档 / 交付格式规范

推荐素材侧以后按三件套交付（可仍附 PDF 给人读）：

### A. `scene_manifest.yaml`（或 JSON）— 场景元数据

```yaml
scene_id: a1111111-1111-4111-8111-111111111101
slug: hair_care
title: 洗头陪伴
duration_seconds: 620
playback: phone_speaker_first
script_version: 4
layers: [ambience, environment, trigger, voice]
volume_policy:
  voice_reference_db: 0
  ambience_db: [-20, -14]
  action_db: [-12, -8]
  near_touch_db: [-10, -6]
  duck_others_when_voice_db: -4
gaps:
  - voice_phrase_masters_missing
  - assets_are_ref_only
```

### B. `tracks.csv` — 轨与文件

| track_id | resource_key | layer | loop | file | usage | status |
|----------|--------------|-------|------|------|-------|--------|
| …508 | hair_wash_water_cycle | environment | true | dw_ref_….wav | A01 | ref |

### C. `timeline.json` — 与客户端契约一致（见 `docs/scene-timeline-contract.md`）

直接交付可校验的 `SceneTimeline`：`phrases[]` + `cues[]`（含 `play_phrase` / `play_oneshot` / `set_envelope` / `set_position` / `fade_*`），并带：

- 稳定 UUID（phrase / cue / track）
- `review_status`（人声授权）
- `script_version` / `asset_status: ref|master`

人工可读的 PDF/表格可作为 **附录**，但 **以 JSON 为唯一真相源**，避免二次转录误差。

### 可选 D. `qc_checklist.md`

外放 / 耳机各听一遍；检查：人声不叠动作入点、结尾 ≥10s 静默、无 A08/A09、无削波。

---

维护：改脚本时先改 `hair_care_timeline_v4.json`（双路径保持一致），再升 `version`，并同步 Mock 轨清单与 `seed_catalog`。
