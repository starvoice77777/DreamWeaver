# DreamWeaver 场景创建规范

版本：`scene-creation-spec-v1.1`  
工程契约：`docs/scene-timeline-contract.md`（`timeline-contract-v1`）  
适用对象：产品、素材/录音、后端、iOS、测试  
更新说明：修正 `angle` 为**弧度**，并补齐职责与入库边界。

## 1. 基本结论

- 素材同学可以按本规范收集、命名、处理并提交母带。
- `timeline.json` 不是素材侧单独产出物；由**产品定义体验节奏，后端按契约落盘并校验**。
- `timeline.json` 是已校验场景的工程真相源；Word/PDF/协同表只用于审阅，不得反向人工转录 JSON。
- `ref` 是参考/原型素材状态，不能进入正式 Bundle 或被标记为可上架。

---

## 2. 职责边界

| 角色 | 必须交付 | 不应单独决定 |
| --- | --- | --- |
| 产品 | 场景目标、体验节奏、协同表、默认空间意图、验收口径 | 许可证有效性、JSON 最终 schema 细节 |
| 素材 / 录音 | WAV 母带、命名、`tracks.csv` 素材字段、来源/许可证、听感备注 | 独立编写最终 `timeline.json`、把 `ref` 升为 `master` |
| 后端 | `scene_manifest`、`timeline.json`、UUID、schema 校验、catalog / fixture | 替素材判断听感与版权 |
| iOS | 按契约调度、音频空间映射、手动覆盖、外放/耳机验证 | 修改官方时序语义而不升版本 |
| 测试 | 机器校验与外放/耳机试听记录 | 用主观判断替代状态/许可证门禁 |

素材侧在没有产品时间线稿时，只提交 `tracks.csv` + 母带 + 许可证 + 需求卡；不必虚构可上线的 `timeline.json`。

---

## 3. 标准场景交付包

```text
scenes/{scene_slug}/
  scene_manifest.yaml      # 产品 + 后端
  tracks.csv               # 素材 + 后端
  timeline.json            # 产品 + 后端，唯一工程时序来源
  qc_checklist.md          # 测试 + 产品
  review.md                # 人工协同附录（可选）
```

| 文件 | 是否工程必需 | 说明 |
| --- | --- | --- |
| `scene_manifest.yaml` | 是 | 场景元数据、体验约束、版本、缺口 |
| `tracks.csv` | 是 | 轨、文件、短键、状态、默认混音与许可证 |
| `timeline.json` | 是 | 通过 `timeline-contract-v1` 校验后方可进工程 |
| `qc_checklist.md` | 是 | 机器检查与人工试听的可追踪项 |
| Word/PDF 协同表 | 否 | 创意和审阅附录 |

---

## 4. 命名、短键与状态

### 4.1 母带长文件名

```text
dw_{用途}_{图层}_{语义}_{播放}_{场景}_{变体}_{版本}_{take}.{ext}
```

仅使用小写英文与下划线。用途为 `official` / `life` / `voice` / `seed` / `ref`；图层为 `env` / `amb` / `trg` / `vox`。

```text
dw_official_env_rain_soft_loop_sc_rain_far_v01_t01.wav
dw_official_trg_hair_towel_oneshot_sc_hair_soft_v01_t01.wav
dw_voice_vox_phrase_hair_care_oneshot_sc_hair_mom_v01_t03.wav
```

`resource_key` 是应用使用的短键，如 `rain_soft`、`hair_towel`；它不等于已获得可用母带。只有填写实际母带名、许可证与 `asset_status=master` 的轨，才可正式分发。

### 4.2 场景缩写

| 缩写 | 场景 | 缩写 | 场景 |
| --- | --- | --- | --- |
| `sc_hair` | 洗头陪伴 | `sc_rain` | 檐下听雨 |
| `sc_firefly` | 深林萤火 | `sc_mist` | 雾岸听潮 |
| `sc_stream` | 幽谷清流 | `sc_lake` | 月下静湖 |
| `sc_star` | 星河远眠 | `sc_lamp` | 暖灯陪伴 |
| `sc_snow` | 雪夜书房 | `sc_wheat` | 风过麦田 |
| `sc_cloud` | 云间呼吸 | `sc_insect` | 夏夜虫鸣 |
| `sc_fire` | 炉边低语 | `sc_any` | 多场景共用 |

### 4.3 素材状态

`planned` → `raw` → `ref` / `qc_pending` → `master`；被替换后为 `deprecated`。`ref`、`raw`、`qc_pending` 不得进入正式 Bundle。

---

## 5. `tracks.csv` 最小字段

| 字段 | 要求 |
| --- | --- |
| `track_id` | 稳定 UUID；供 cues 引用 |
| `resource_key` | 仅 `a-z0-9_` |
| `layer` | `environment` / `ambience` / `trigger` / `voice`；官方睡眠场景默认不用 `music`。若客户端需 `music`，须先扩展命名与契约后再使用。 |
| `loop` | 与实际素材一致；不可循环素材不得填 `true` |
| `master_file` | 实际母带长文件名；未有留空 |
| `asset_status` | `planned` / `raw` / `ref` / `qc_pending` / `master` / `deprecated` |
| `default_volume` | `0.00–1.00` 的工程值 |
| `angle_rad` / `radius` | 默认空间值，见第 7 节 |
| `license_status` | `approved` / `pending` / `not_required` |
| `usage` | 简短用途与听感备注 |

起始混音建议：环境底层 `0.18–0.28`，主环境 `0.32–0.46`，近耳触感 `0.40–0.52`，人声 `0.62–0.75`。最终以手机外放试听为准。

---

## 6. 两种场景创建模板

### A. 有人声 + 文本的过程型场景

适用：洗头陪伴、面部护理。规则：

1. 先写“短句 + 长留白”稿，任意 30 秒最多 1 句；成品短句建议 5–12 秒。
2. 每句建立独立 `phrase_id`，记录文本、真实音频时长、`review_status` 与 `voice_binding`。
3. 人声只能使用 `official_resource`、`system` 或已授权的 `authorized_asset`。
4. 每句人声开始时，必须用明确的 `set_volume` cue 使环境轨 duck；句尾真实时长 + 300ms 后恢复。
5. 喷雾、毛巾、按压等动作为 `play_oneshot`；不循环。
6. 人声未交付时，`asset_status` 必须为 `planned` / `ref`，占位资源仅供演示。

### B. 无文本 + 无人声的环境型场景

适用：檐下听雨、幽谷清流、月下静湖。规则：

1. `phrases` 固定为 `[]`，不绑定 voice 轨。
2. 使用 2–3 条轨：底层环境、主特征环境、可选缓慢变化轨。
3. 时间线可使用 `play`、`set_volume`、`set_position`、`fade_in`、`fade_out`。
4. 变化间隔至少 90 秒，单次 `volume` 变化不超过 0.08；不得使用突然事件、音乐、雷声、鸟叫或快速绕头。
5. 结尾只可整体淡出，或平滑接入用户已选底噪；不得硬停。

---

## 7. `timeline.json` 工程规则

### 7.1 主时钟与版本

- 使用 `timeline-contract-v1` 的 `phrases[]` 与 `cues[]`。
- `at_seconds` 是场景开始后的唯一主时钟；时序、文案、轨、混音或默认位置变化均使 `version + 1`。
- 每个 `phrase_id`、`cue_id`、`track_id` 使用稳定 UUID。
- 官方种子 `manual_override_track_ids=[]`；用户手动调过的轨退出后续官方自动化。

### 7.2 空间坐标：JSON 只用弧度

| 字段 | 范围 | 工程约定 |
| --- | --- | --- |
| `angle` | `-π…π`，单位为**弧度** | `0` 正前，`-π/2` 左侧，`π/2` 右侧，`±π` 后方 |
| `radius` | `0…1` | `0` 近，`1` 远 |
| `volume` | `0…1` | 客户端最终播放增益 |
| `fade_ms` | 正整数毫秒 | 淡入、淡出、音量变化的过渡时间 |

面向人填写的协同表可以用“左侧 / 右前 / 偏远”或角度制；**导入 JSON 前由产品/后端换算成弧度**，JSON 中不得写 `90`、`180` 等度数。

`set_position` 的平滑插值能力由客户端确认：若当前客户端不支持位置渐变，时间线只记录目标 `angle` / `radius`，并在 `qc_checklist.md` 标为“离散定位，待客户端平滑化”；不得假定 `fade_ms` 自动作用于位置。

### 7.3 Cue action 约束

| action | 必填或推荐字段 |
| --- | --- |
| `play_phrase` | `phrase_id`、`track_id` |
| `play_oneshot` | `track_id` |
| `play` / `pause` | `track_id` |
| `set_volume` | `track_id`、`volume`、`fade_ms` |
| `set_position` | `track_id`、`angle`（弧度）、`radius` |
| `fade_in` / `fade_out` | `track_id`、`fade_ms` |
| `enable` / `disable` | `track_id` |
| `replace_source` | `track_id`、`resource_key` 或 `asset_id` |

未知 action 由旧客户端忽略，不应中断后续调度。

---

## 8. 素材收集、处理与提交

### 8.1 先建需求，再收集

素材同学先在 `tracks.csv` 建 `planned` 行，写清：`resource_key`、规范母带名、图层、loop/oneshot、目标听感、时长、需避免声音、优先级、许可证要求、场景用途。

### 8.2 技术处理

| 类型 | 时长 | 要求 |
| --- | --- | --- |
| 环境 / 氛围 `loop` | 30–180 秒 | 48kHz 立体声 WAV；首尾可接，或标明 `requires_engine_crossfade=true` |
| 触发 `trg + oneshot` | 1–5 秒 | 精确裁剪、淡入淡出、无削波，不标 loop |
| 人声 `vox + oneshot` | 5–12 秒 | 逐句成品、前后 100–300ms 静音、完成授权；种子录音与成品分开 |

交付：WAV（PCM）母带 + 可选 48kHz AAC/M4A。素材收集侧不直接把音频塞进 Bundle；后端依据 `tracks.csv` 转码、绑定短键与入库。

### 8.3 音量、动态与声学质量规范

**处理原则：先统一素材自身响度，再用 `timeline.json` 的 `volume` 完成场景层级。** 不允许用“把某条轨调到 0.95、另一条调到 0.06”补救来源响度失衡。

| 类型 | 交付综合响度 | 真峰值 | 动态 / 细节要求 | 默认工程音量起点 |
| --- | --- | --- | --- |
| 环境底层 `environment + loop` | `-25 ±2 LUFS` | ≤ `-3 dBTP` | 稳定、不应有突然爆点；适合长时间垫底 | `0.18–0.28` |
| 主环境 `ambience + loop` | `-23 ±2 LUFS` | ≤ `-3 dBTP` | 保留雨、叶、水等质感；循环后不应出现明显强弱跳变 | `0.32–0.46` |
| 触发 `trigger + oneshot` | `-22 ±2 LUFS` | ≤ `-3 dBTP` | 1–5 秒内动作清楚，但不能比环境突然大一截 | `0.35–0.50` |
| 人声 `voice + oneshot` | `-18 ±1 LUFS` | ≤ `-3 dBTP` | 字音清晰、无爆破音；作为同一时刻最清楚的层 | `0.62–0.75` |

以下项目必须在 `qc_checklist.md` 留下测量或试听结论：

1. 采样率 48kHz；环境/氛围交付为立体声，人声可单声道或立体声。
2. 无削波、直流偏移、稳定电流嗡声、明显底噪抽吸、爆破音或突兀高频刮擦。
3. 立体声素材需做单声道下混试听，不得出现明显相位抵消或主要声源消失。
4. `loop=true` 的素材循环至少 2 分钟；首尾无明显断点、重复感或响度跳变。不能自然闭环时，`tracks.csv` 必须填 `requires_engine_crossfade=true`。
5. 同一场景内，非人声轨的 `default_volume` 原则上应落在 `0.15–0.55`；超过范围须说明原因。人声通常不低于主环境，若例外必须在协同表说明。
6. 所有淡入淡出和音量变化必须由 cue 的 `fade_ms` 表达；环境变化通常不少于 1500ms，结束淡出通常不少于 8000ms。

### 8.4 短提示 / 人声文案规范

短提示只用于**过程型有人声场景**。无文本环境型场景固定 `phrases: []`，不得为了“丰富内容”加入人声、文字或音乐。

| 维度 | 要求 |
| --- | --- |
| 信息量 | 只描述当下动作、感觉或许可休息的状态；不讲故事、不讲道理、不追问用户 |
| 句式 | 一句为主，最多两个短分句；用陈述或温和提示，不用感叹号、连续问句、命令式催促 |
| 时长 | 成品语音 5–12 秒；过短不足以形成陪伴，超过 12 秒会增加认知负担 |
| 频率 | 任意 30 秒最多 1 句；两句之间至少留 10 秒纯声音或安静 |
| 语气 | 低信息、具体、温和；避免评价用户、制造紧迫感或要求即时回应 |
| 场景对应 | 人声必须与已发生或即将发生的动作声对应；提示通常比动作声早 1–3 秒 |
| 声音关系 | 人声开始时其他轨 duck 约 4dB；人声真实时长结束后 300ms 再恢复 |
| 合规 | 不作医疗、疗效或诊断承诺；可识别声线仅使用经授权的 `authorized_asset` 或官方资源 |

可用示例：

```text
“水温已经调好了，慢慢靠近一点。”
“这里慢一点，放松就好。”
“现在不用再配合什么了。”
```

不建议：

```text
“你怎么还不睡？明天会更好的。”      # 评价/压力/抽象劝慰
“接下来我要讲一个故事给你听……”        # 高信息量叙事
“立刻闭上眼睛，必须放松下来。”          # 强命令与紧迫感
```

每条短提示在 `phrases[]` 中必须记录：`phrase_id`、精确文本、真实音频时长、`review_status`、`voice_binding`、授权状态。脚本文案改动、声线替换或真实时长变化都要求 `timeline.version + 1`。

### 8.3 许可证

网络视频、ASMR 成品等只能作为 `ref`。可识别真人声线须有书面授权；授权、来源 URL、署名要求与审核状态写进素材清单。`ref` 转 `master` 前必须补齐许可证与 QC。

---

## 9. 入工程门禁与 QC

### 9.1 允许进 catalog 的条件

1. `timeline.json` 通过 `timeline-contract-v1` schema 校验。
2. 全部 cue / phrase 引用的 `track_id` 存在于 `tracks.csv`。
3. `angle` 是弧度且在 `-π…π`，`radius`、`volume`、`fade_ms` 合法。
4. 正式场景引用的轨均为 `asset_status=master` 且 `license_status=approved`。
5. `loop=true` 的轨已验收循环，或有 `requires_engine_crossfade=true`。

### 9.2 人工试听

- 手机外放：不依赖耳机才听得懂；人声不被环境盖住。
- 耳机：不快速绕头、不突然贴耳。
- 有人声：每 30 秒最多一句；duck 和恢复时点正确。
- 无文本：至少 2 分钟无明显接缝；环境变化不打断入睡感。
- 结尾：最后 10 秒可预期淡出或平滑切换，绝不硬停。

---

## 10. 变更流程

```text
产品定义 → tracks planned → 素材收集/处理 → 产品+后端编写 timeline
→ schema 校验 → iOS 外放/耳机试听 → QC/授权通过 → master 入库
```

先改 `timeline.json`，再更新 Word/PDF 附录。替换母带但语义不变时，母带名升 `vXX`；任何可听内容或时序改动都使 `timeline.version + 1`。
