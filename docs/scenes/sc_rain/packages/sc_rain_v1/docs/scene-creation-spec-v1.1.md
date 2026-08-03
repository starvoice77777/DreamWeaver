# DreamWeaver 场景创建规范

版本：`scene-creation-spec-v1.1-rev3`  
工程契约：`docs/scene-timeline-contract.md`（`timeline-contract-v1`）  
适用对象：产品、素材/录音、后端、iOS、测试  
更新说明：保留弧度空间坐标与素材验收口径；移除用户语音克隆/声样录入能力，并将用户自定义场景改为视频式音频轨道 + 多位置关键帧模型。

## 1. 基本结论

- 素材同学可以按本规范收集、命名、处理并提交母带。
- 产品不提供用户语音克隆、声样录入、亲友声线创建或个人声音包；含人声的场景仅可引用审核通过的官方人声资源或系统朗读。
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
| `tracks.csv` | 是 | 轨、文件、短键、状态、默认混音与许可证；人声轨仅标记为官方或系统来源 |
| `timeline.json` | 是 | 通过 `timeline-contract-v1` 校验后方可进工程 |
| `qc_checklist.md` | 是 | 机器检查与人工试听的可追踪项 |
| Word/PDF 协同表 | 否 | 创意和审阅附录 |

---

## 4. 命名、短键与状态

### 4.1 母带长文件名

```text
dw_{用途}_{图层}_{语义}_{播放}_{场景}_{变体}_{版本}_{take}.{ext}
```

仅使用小写英文与下划线。用途为 `official` / `life` / `voice` / `ref`；图层为 `env` / `amb` / `trg` / `vox`。`voice` 仅用于审核通过的官方人声或系统朗读成品，禁止保存用户声样或克隆产物。

```text
dw_official_env_rain_soft_loop_sc_rain_far_v01_t01.wav
dw_official_trg_hair_towel_oneshot_sc_hair_soft_v01_t01.wav
dw_official_vox_phrase_hair_care_oneshot_sc_hair_soft_v01_t03.wav
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
| `asset_duration_seconds` | 母带真实时长；只描述文件，不等于场景中的需求时长 |
| `requires_engine_crossfade` | 短循环素材是否必须由播放器进行循环交叉淡化 |
| `crossfade_ms` | 循环交叉淡化时长；不需要时填 `0` |
| `license_status` | `approved` / `pending` / `not_required` |
| `usage` | 简短用途与听感备注 |

起始混音建议：环境底层 `0.18–0.28`，主环境 `0.32–0.46`，触发短音 `0.35–0.50`，人声 `0.62–0.75`。最终以手机外放与耳机试听为准。

正式升为 `master` 前，还必须在 `tracks.csv` 或 `qc_checklist.md` 记录 `measured_lufs`、`true_peak_dbtp`、测量工具与测量日期。若当前工程清单尚未接收这些列，则先写入 QC 文件，不得省略测量记录。

---

## 6. 场景创建模板

### A. 有人声 + 文本的过程型场景

适用：洗头陪伴、面部护理。规则：

1. 先写“短句 + 长留白”稿，任意 30 秒最多 1 句；成品短句建议 5–12 秒。
2. 每句建立独立 `phrase_id`，记录文本、真实音频时长、`review_status` 与 `voice_binding`。
3. 人声只能使用 `official_resource` 或 `system`；不得引用、上传或生成用户、亲友或第三方可识别声线。
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

### C. 用户自定义的时间戳场景

适用：从空白场景创建，或复制预设后改编。用户以视频剪辑式时间轴安排声音：一个声音对象对应一条音频轨，轨道的左边界就是播放开始时间；不以文本进度、语音内容或外部触发作为排程依据。

1. **不预设场景总时长。** 用户直接进入画布和时间轴。场景时长由最晚结束的音频轨自动推导；播放页的定时关闭是独立设置，不回写为创作时长。
2. 用户把一个声音拖入画布时，系统立即创建一条音频轨，并默认放在当前时间轴游标（首次为 `00:00`）。轨道保存 `start_seconds`、素材原始 `asset_duration_seconds`、播放片段时长和默认音量。
3. 时间轴中的轨道以“左边界 = 开始时间、宽度 = 音频时长”显示；用户拖动轨道可调整 `start_seconds`。轨道须显示素材名称、`mm:ss` 格式的起始时间和原始音频时长。普通音频到达素材尾部自然结束。
4. 每条轨道有 `position_keyframes[]`：默认在轨道开始时间创建第一帧。用户可在轨道内新增、移动或删除位置关键帧，并在画布中设置该帧的 `angle` 和 `radius`。客户端在相邻关键帧之间呈现平滑位置过渡；具体平滑计算不在本规范中规定。
5. 后端必须按音频引擎统一的听者坐标系和左右耳禁行区参数，校验每一对相邻位置关键帧之间的**完整运动路径**。路径不得进入或穿过任一耳部禁行区；不得只比较两个端点。校验失败时不得保存，并返回冲突轨、关键帧和“路径经过人耳区域”的可读错误。
6. `loop=true` 的素材默认播放一轮原始时长。拖动轨道右边界时，右边界就是该轨的明确停止时间，`playback_duration_seconds = right_edge_seconds - start_seconds`；系统仅在这段时间内循环原音频，并在右边界处按轨道淡出设置结束。短循环素材若标记 `requires_engine_crossfade=true`，每一轮按 `crossfade_ms` 交叉淡化。这只改变本轨播放片段，不创建全局总时长。
7. 保存时，编辑器把轨道模型编译为 `cues[]`：在 `start_seconds` 写入播放动作，并在每个位置关键帧的时间戳写入 `set_position` 动作。任一轨道起始时间、播放片段、空间位置、音量或朗读文本改动均使 `timeline.version + 1`。

---

## 7. `timeline.json` 工程规则

### 7.1 主时钟与版本

- 使用 `timeline-contract-v1` 的 `phrases[]` 与 `cues[]`。
- `at_seconds` 是场景开始后的唯一主时钟；用户自定义场景的 `at_seconds` 由每条音频轨的 `start_seconds` 编译产生，禁止以文本进度、语音识别结果或相对触发作为排程字段。时序、文案、轨、混音或默认位置变化均使 `version + 1`。
- 用户自定义场景使用 `automation_mode=user_timestamp`；官方预设可使用 `official_auto`，但复制为用户场景后，新增或改写的音频轨必须显式保存 `start_seconds` 与 `position_keyframes[]`。
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

`volume` 是独立混音增益，**不得写入距离效果**。拖动远近只改变空间位置及客户端衰减；当前新声源的默认混音增益为 `0.72`，因此素材母带响度不齐会在首次加入时直接暴露。若客户端默认值调整，iOS 与本规范需同步更新。

`set_position` 的平滑插值能力由客户端确认：若当前客户端不支持位置渐变，时间线只记录目标 `angle` / `radius`，并在 `qc_checklist.md` 标为“离散定位，待客户端平滑化”；不得假定 `fade_ms` 自动作用于位置。

### 7.3 位置关键帧的路径安全

- 每条用户音频轨至少有一个位置关键帧，第一帧的 `at_seconds` 必须等于该轨 `start_seconds`；后续帧必须落在该轨播放片段内并按时间递增。
- 后端负责验证每两个相邻位置关键帧之间的完整运动路径。使用音频引擎约定的听者坐标系与左右耳禁行区参数；任何路径穿过禁行区均为非法。
- 本规范只要求平滑过渡与完整路径校验，不规定客户端的平滑算法、缓动曲线或采样实现。后端的职责是拒绝会经过人耳区域的路径，而不是替客户端生成运动效果。

### 7.4 Cue action 约束

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

### 7.5 素材时长与需求时长适配

**素材文件时长和声音在场景中的需求时长相互独立。** `asset_duration_seconds` 记录文件物理长度；`start_seconds`、`playback_duration_seconds` 与停止 cue 决定它在场景中实际播放多久。不得为了匹配时间戳，把所有素材机械裁成相同长度或进行明显变速。

| 时长关系 | 标准处理 |
| --- | --- |
| 循环环境音短于需求区间 | `loop=true`，循环到轨道右边界或停止 cue；需要时设置 `requires_engine_crossfade=true` 与 `crossfade_ms` |
| 环境音长于需求区间 | 只播放需求区间，结束前 `fade_out`，随后 `pause` / `disable`；不得硬切 |
| 触发音短于动作阶段 | 保持 `oneshot`；在阶段内分散播放不同变体，中间由环境底层承接，不机械循环同一短音 |
| 触发音长于动作阶段 | 优先调整动作时序；必须缩短时重新裁剪并增加 100–500ms 淡出 |
| 人声与预计时长不一致 | 以最终音频真实时长为准，更新 `phrases[]` 和后续 cues；不得通过明显加速强行贴合时间戳 |

时间戳协同表至少记录：需求开始时间、需求结束时间、需求持续时间、素材真实时长、`loop/oneshot`、交叉淡化、淡入淡出、重复策略、实际文件名和缺失处理。需求持续时间不得从素材文件长度反推。

例如，11.596 秒的室内远雨需要贯穿 180 秒场景时，只建立一次播放窗口：

```text
00:00  play；volume 从 0 淡入到默认值
00:00–03:00  引擎循环素材；每轮交叉淡化 1000ms
02:50  fade_out 10000ms
03:00  pause / disable
```

若契约只接受数值 `at_seconds`，产品必须在场景总时长确定后，把“场景结束前 10 秒”等相对描述换算为绝对秒数，再交后端校验。

### 7.6 用户场景的音频轨 JSON 示例

```json
{
  "scene_id": "stable-user-scene-uuid",
  "version": 1,
  "automation_mode": "user_timestamp",
  "timeline_model": "audio_tracks_v1",
  "derived_duration_seconds": 38.4,
  "phrases": [],
  "audio_tracks": [
    {
      "track_id": "rain-track-uuid",
      "asset_id": "rain-asset-uuid",
      "start_seconds": 0,
      "asset_duration_seconds": 38.4,
      "playback_duration_seconds": 38.4,
      "volume": 0.28,
      "position_keyframes": [
        {"at_seconds": 0, "angle": -0.35, "radius": 0.85},
        {"at_seconds": 20, "angle": 0.35, "radius": 0.85}
      ]
    },
    {
      "track_id": "towel-track-uuid",
      "asset_id": "towel-asset-uuid",
      "start_seconds": 12,
      "asset_duration_seconds": 2.1,
      "playback_duration_seconds": 2.1,
      "volume": 0.42,
      "position_keyframes": [
        {"at_seconds": 12, "angle": 0.2, "radius": 0.35}
      ]
    }
  ],
  "cues": [
    {
      "id": "cue-001",
      "at_seconds": 0,
      "actions": [
        {"type": "set_position", "track_id": "rain-track-uuid", "angle": -0.35, "radius": 0.85},
        {"type": "play", "track_id": "rain-track-uuid"}
      ]
    },
    {
      "id": "cue-002",
      "at_seconds": 12,
      "actions": [
        {"type": "set_position", "track_id": "towel-track-uuid", "angle": 0.2, "radius": 0.35},
        {"type": "play_oneshot", "track_id": "towel-track-uuid"}
      ]
    },
    {
      "id": "cue-001-position-2",
      "at_seconds": 20,
      "actions": [
        {"type": "set_position", "track_id": "rain-track-uuid", "angle": 0.35, "radius": 0.85}
      ]
    }
  ]
}
```

界面以时间轴轨道展示 `00:00`、`00:12` 等起始时间和音频长度；不得只保存“稍后出现”“跟随文本”等不可复现的描述，也不得要求用户先填写场景总时长。

---

## 8. 素材收集、处理与提交

### 8.1 先建需求，再收集

素材同学先在 `tracks.csv` 建 `planned` 行，写清：`resource_key`、规范母带名、图层、loop/oneshot、目标听感、时长、需避免声音、优先级、许可证要求、场景用途。

### 8.2 技术处理

| 类型 | 时长 | 要求 |
| --- | --- | --- |
| 环境 / 氛围 `loop` | 30–180 秒 | 48kHz 立体声 WAV；首尾可接，或标明 `requires_engine_crossfade=true` |
| 触发 `trg + oneshot` | 1–5 秒 | 精确裁剪、淡入淡出、无削波，不标 loop |
| 人声 `vox + oneshot` | 5–12 秒 | 官方/系统逐句成品、前后 100–300ms 静音、来源可追溯；不得含用户声样或克隆音频 |

交付：WAV（PCM）母带 + 可选 48kHz AAC/M4A。素材收集侧不直接把音频塞进 Bundle；后端依据 `tracks.csv` 转码、绑定短键与入库。

### 8.3 音量、动态与声学质量规范

**处理原则：先统一素材自身响度，再用 `timeline.json` 的 `volume` 完成场景层级。** 不允许用“把某条轨调到 0.95、另一条调到 0.06”补救来源响度失衡。

| 类型 | 交付综合响度 | 真峰值 | 动态 / 细节要求 | 默认工程音量起点 |
| --- | --- | --- | --- |
| 环境底层 `environment + loop` | `-25 ±2 LUFS` | ≤ `-3 dBTP` | 稳定、不应有突然爆点；适合长时间垫底 | `0.18–0.28` |
| 主环境 `ambience + loop` | `-23 ±2 LUFS` | ≤ `-3 dBTP` | 保留雨、叶、水等质感；循环后不应出现明显强弱跳变 | `0.32–0.46` |
| 触发 `trigger + oneshot` | `-22 ±2 LUFS` | ≤ `-3 dBTP` | 1–5 秒内动作清楚，但不能比环境突然大一截 | `0.35–0.50` |
| 人声 `voice + oneshot` | `-18 ±1 LUFS` | ≤ `-3 dBTP` | 字音清晰、无爆破音；作为同一时刻最清楚的层 | `0.62–0.75` |

素材侧简化口径：循环环境约 `-27～-21 LUFS`，触发短音约 `-24～-20 LUFS`，人声短句约 `-19～-17 LUFS`；**所有类型的真峰值都必须 ≤ `-3 dBTP`**。`-1 dBTP` 不属于本项目的交付范围，不能与“≤ `-3 dBTP`”混用。

测量与处理顺序：

1. 30 秒以上循环轨以 **Integrated LUFS** 为主；1–12 秒的触发音和短句可同时记录 Integrated 与 Short-term，验收时采用工具能够稳定输出且团队约定的读数。
2. 先测原始文件，再以整体增益或轻量动态处理接近目标 LUFS；不得为了追数值造成抽吸、失真或触发音被压扁。
3. 使用 true-peak limiter 将上限设为 `-3 dBTP`，处理后重新测量；普通 sample peak 或 `dBFS` 不能代替 `dBTP` 验收。
4. 将最终 LUFS、dBTP、工具及版本写入 QC，再进行手机外放、耳机与多轨叠加试听。
5. 工具只有峰值表、不能测 LUFS 或 true peak 时，素材最多进入 `qc_pending`，不得升为 `master`。可使用 Youlean Loudness Meter 或 ffmpeg `loudnorm` / `ebur128` 完成正式测量。

以下项目必须在 `qc_checklist.md` 留下测量或试听结论：

1. 采样率 48kHz；环境/氛围交付为立体声，人声可单声道或立体声。
2. 无削波、直流偏移、稳定电流嗡声、明显底噪抽吸、爆破音或突兀高频刮擦。
3. 立体声素材需做单声道下混试听，不得出现明显相位抵消或主要声源消失。
4. `loop=true` 的素材循环至少 2 分钟；首尾无明显断点、重复感或响度跳变。不能自然闭环时，`tracks.csv` 必须填 `requires_engine_crossfade=true`。
5. 同一场景内，非人声轨的 `default_volume` 原则上应落在 `0.15–0.55`；禁止依赖极端增益补救母带差异。人声通常不低于主环境，若例外必须在协同表说明。
6. 所有淡入淡出和音量变化必须由 cue 的 `fade_ms` 表达；环境变化通常不少于 1500ms，结束淡出通常不少于 8000ms。
7. 多轨同时播放时不得削波或被单轨掩蔽；人声出现时，环境与触发轨统一 duck 约 `4 dB`，句尾真实时长 + 300ms 后平滑恢复。

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
| 合规 | 不作医疗、疗效或诊断承诺；仅使用官方资源或系统朗读，不提供可识别个人声线的克隆、上传或创建 |

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

每条短提示在 `phrases[]` 中必须记录：`phrase_id`、精确文本、真实音频时长、`review_status`、`voice_binding`（仅 `official_resource` 或 `system`）与来源状态。脚本文案改动、朗读来源替换或真实时长变化都要求 `timeline.version + 1`。

### 8.5 许可证

网络视频、ASMR 成品等只能作为 `ref`。官方人声须记录来源、许可证、署名要求与审核状态；不得收集用户、亲友或第三方声样。`ref` 转 `master` 前必须补齐许可证与 QC。

---

## 9. 入工程门禁与 QC

### 9.1 允许进 catalog 的条件

1. `timeline.json` 通过 `timeline-contract-v1` schema 校验。
2. 全部 cue / phrase 引用的 `track_id` 存在于 `tracks.csv`。
3. `angle` 是弧度且在 `-π…π`，`radius`、`volume`、`fade_ms` 合法。
4. 正式场景引用的轨均为 `asset_status=master` 且 `license_status=approved`。
5. `loop=true` 的轨已验收循环，或有 `requires_engine_crossfade=true`。
6. 每条 `master` 轨已有 LUFS、true peak、工具与日期记录，并满足第 8.3 节对应图层范围。
7. `automation_mode=user_timestamp` 的场景中，每个 `audio_track.start_seconds ≥ 0`，每条轨都有按时间递增的 `position_keyframes[]`，第一帧 `at_seconds = start_seconds`，所有帧均在本轨播放片段内；后端已通过相邻关键帧路径的耳部禁行区校验；`derived_duration_seconds` 等于所有轨道 `start_seconds + playback_duration_seconds` 的最大值。

### 9.2 人工试听

- 手机外放：不依赖耳机才听得懂；人声不被环境盖住。
- 耳机：不快速绕头、不突然贴耳。
- 有人声：仅使用官方/系统朗读；每 30 秒最多一句；duck 和恢复时点正确。
- 用户自定义场景：把声音拖入画布后自动出现一条轨道；拖动轨道后开始时间、显示时长和多个位置关键帧均可保存、重开；任一关键帧移动路径不得经过左右耳区域。
- 无文本：至少 2 分钟无明显接缝；环境变化不打断入睡感。
- 结尾：最后 10 秒可预期淡出或平滑切换，绝不硬停。

---

## 10. 变更流程

```text
产品定义或用户在时间轴创建 → tracks planned → 素材收集/处理 → 产品+后端（或用户编辑器）编写 timeline
→ schema 校验 → iOS 外放/耳机试听 → QC/授权通过 → master 入库
```

先改 `timeline.json`，再更新 Word/PDF 附录。替换母带但语义不变时，母带名升 `vXX`；任何可听内容或时序改动都使 `timeline.version + 1`。
+

---

## 11. 后端循环播放与交叉淡化执行契约

本节集中定义循环相关字段的含义和执行顺序。其优先级高于 Word/PDF 中的自然语言说明；工程以 `timeline.json` 和 `tracks.csv` 为准。

### 11.1 字段与约束

| 字段 | 类型 | 必填条件 | 含义与约束 |
| --- | --- | --- | --- |
| `loop` | Boolean | 每条音频轨必填 | `true` 表示在本轨播放窗口内重复母带；`false` 表示只播放一次。不得依赖客户端默认值。 |
| `asset_duration_seconds` | Number | 必填 | 音频文件真实物理时长，必须大于 0，以 `ffprobe` 或同等工具实测值为准。 |
| `playback_duration_seconds` | Number | 必填 | 该轨在场景中的实际播放时长，由时间线决定，与母带时长相互独立。 |
| `requires_engine_crossfade` | Boolean | `loop=true` 时必填 | `true` 表示每轮循环必须由播放引擎交叉淡化；`false` 表示母带已验证可以直接无缝循环。 |
| `crossfade_ms` | Integer | `requires_engine_crossfade=true` 时必填 | 每轮重叠淡化时长。通常为 600–1500ms，允许范围 300–2000ms；必须小于母带时长的一半。 |
| `fade_in_ms` / `fade_out_ms` | Integer | 按轨需要 | 轨道进入、退出场景的外层淡入淡出，与循环接缝的 `crossfade_ms` 相互独立。 |

### 11.2 执行规则

1. `loop=false`：只播放一次。若 `playback_duration_seconds > asset_duration_seconds`，时间线必须另有明确替代、静音或后续轨道；不得自动拉伸或擅自循环。
2. `loop=true && requires_engine_crossfade=false`：在本轨播放窗口内按母带原始首尾直接循环。
3. `loop=true && requires_engine_crossfade=true`：当前轮结束前 `crossfade_ms` 启动下一轮，两轮使用等功率曲线交叉淡化；完成后释放上一轮实例。
4. 循环只持续到 `start_seconds + playback_duration_seconds` 或更早的停止 cue。最后一轮允许被截断，但必须先执行轨道 `fade_out`，不得硬停。
5. `set_volume` 控制场景混音层级；距离衰减由空间位置计算。循环交叉淡化不得改变轨道基准 `volume`，也不得把距离写进母带增益。
6. 同一素材在不同时段重复出现且需要从头播放时，应创建两个 `track_id` 实例；不得依赖 `pause` 后再次 `play` 是否自动回到文件开头。

### 11.3 校验与降级

- 以下情况 schema 校验失败：`loop=true` 但缺少 `requires_engine_crossfade`；需要交叉淡化但 `crossfade_ms=0`；交叉淡化时长大于等于母带时长一半；播放时长或母带时长不大于 0。
- 播放端暂不支持工程交叉淡化时，只能改用已预渲染的长版母带，或阻止该场景进入正式 catalog；不得静默降级为有明显断点的硬循环。
- 素材丢失、解码失败或缓存不可用时，停用该轨并保留其余轨道；底层环境轨丢失时，场景应提示资源不完整，不得以突发提示音替代。
- 每次场景验收必须记录：连续循环试听时长、接缝结论、手机外放结论、耳机结论、实际 `crossfade_ms` 与客户端版本。

### 11.4 最小示例

```json
{
  "track_id": "track-uuid",
  "resource_key": "rain_parasol",
  "start_seconds": 30,
  "asset_duration_seconds": 6.05,
  "playback_duration_seconds": 530,
  "loop": true,
  "requires_engine_crossfade": true,
  "crossfade_ms": 1200,
  "default_volume": 0.40
}
```
