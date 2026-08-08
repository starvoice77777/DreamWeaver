# 预设场景编排提交规范

- 版本：`preset-orchestration-submission-v1`
- 日期：2026-08-08
- 适用场景（本轮）：**檐下听雨**、**洗头陪伴**
- 相关契约：`docs/scene-composition-v2-contract.md`、`docs/spatial-audio-renderer-unification-plan.md`

---

## 0. 本轮改什么、不改什么

| 改 | 不改 |
| --- | --- |
| 各素材的**出现 / 消失时间** | 已有 WAV 母带文件（不换文件、不改哈希） |
| **圆盘方位**（左右前后） | `resource_key`、母带长文件名 |
| **听感大小**（用半径表达，见下文） | 采样率、响度母带处理、许可证状态 |
| **移动轨迹**（关键帧序列） | 洗头 20 句人声文案与逐句资源键 |
| **淡入 / 淡出 / 人声 duck** | 场景总时长默认仍为约 **620 秒（10:20）** |
| 循环接缝的 **crossfade 毫秒**（可微调） | 场景类型：雨景无人声；洗头为人声过程型 |

工程侧会把你们填的编排表编译进官方预设（timeline / composition）。**请勿手改最终 JSON**；Word / 协同表只作审阅附录，以本规范要求的 CSV 表为准。

---

## 1. 必须先建立的三个概念

播放页圆盘与时间轴已拆成两层。填表时按这两层思考，不要再把「一条轨 = 一个音量旋钮 + 一个位置」混成一件事。

### 1.1 逻辑声源（SourceGroup）＝ 圆盘上的一个图标

- 拥有：**方位（angle）+ 听感大小（radius）+ 整段轨迹**
- 用户拖动圆盘时，改的是整个逻辑声源
- 例子：洗头的 20 句人声 → **只有一个**「轻声陪伴」图标；阵风两次吹过 → **只有一个**「阵风」图标

### 1.2 音频片段（AudioClip）＝ 时间轴上的一段声音

- 拥有：引用哪个 `resource_key`、从第几秒播到第几秒、oneshot / loop、淡入淡出、loop 交叉淡化
- **不单独占一个圆盘图标**（除非它是该组的唯一片段）

### 1.3 「声音大小」只能用半径，不能再写稳态 volume

| 你想表达的听感 | 填什么 | 不要填什么 |
| --- | --- | --- |
| 这一层长期比另一层更响 / 更轻 | 改 **radius**（越靠近圆心越响） | 不要再依赖 `default_volume` 做主次 |
| 雨势慢慢变大 / 变小 | 在轨迹关键帧里改 **radius** | 不要写「把 volume 从 0.2 调到 0.4」当稳态 |
| 声音从无到有、从有到无 | `fade_in_ms` / `fade_out_ms` | 不要用快速挪半径假装淡入淡出 |
| 人声说话时背景让一点 | `duck_db` + 起止时间 | 不要把背景图标挪远再挪回 |

内部仍有素材响度校准（让不同母带在同一半径下可比），**素材同学本轮不用改母带**。

---

## 2. 圆盘坐标怎么填

### 2.1 方位 angle

工程 JSON 使用**弧度**。提交表可用**角度制**，工程导入时换算。

| 听感位置 | 角度（推荐填写） | 弧度（工程） |
| --- | ---: | ---: |
| 正前 | `0°` | `0` |
| 右前 | `+45°` | `+π/4 ≈ +0.79` |
| 正右 | `+90°` | `+π/2 ≈ +1.57` |
| 右后 | `+135°` | `≈ +2.36` |
| 正后 | `±180°` | `±π ≈ ±3.14` |
| 左后 | `-135°` | `≈ -2.36` |
| 正左 | `-90°` | `-π/2 ≈ -1.57` |
| 左前 | `-45°` | `-π/4 ≈ -0.79` |

规则：

- 范围：`-180° … +180°`（或弧度 `-π … +π`）
- 两关键帧之间按**最短角差**连续移动（从 +170° 到 -170° 会走 20° 短路径，不会绕一整圈）
- 禁止「快速绕头」：相邻关键帧若角差很大，必须拉长移动时间（雨景 / 洗头建议单次明显位移 **≥ 20–30 秒**）

### 2.2 听感大小 radius（唯一稳态音量）

`radius` 范围 `0 … 1`：

- `0`＝圆心＝最响（约 0 dB）
- `1`＝圆盘边缘＝接近无声（约 -40 dB）

当前工程曲线（供对照，不必手算）：

| radius | 约等于相对圆心衰减 |
| ---: | ---: |
| 0.38 | ≈ -0.5 dB（人声建议起点） |
| 0.50 | ≈ -1.2 dB |
| 0.62 | ≈ -2.2 dB |
| 0.70 | ≈ -3.5 dB |
| 0.80 | ≈ -6.1 dB |
| 0.85 | ≈ -8.1 dB |
| 0.90 | ≈ -11.1 dB |
| 0.95 | ≈ -16.4 dB |
| 1.00 | ≈ -40 dB |

**填表建议**：直接写目标听感层级（如「比人声轻约 12 dB」），并给出对应 `radius`；若只会写相对 dB，工程可按曲线反算。

层级参考（本轮验收口径）：

**洗头陪伴**

| 层 | 相对人声 | 建议 radius 起点 |
| --- | --- | --- |
| 轻声陪伴（人声） | 0 dB 参考 | `0.35–0.42` |
| 近耳触感（毛巾 / 泡沫近） | 约 -6…-10 dB | `0.80–0.90` |
| 动作（打湿 / 冲洗等） | 约 -8…-12 dB | `0.85–0.92` |
| 环境底层（远水循环等） | 约 -14…-20 dB | `0.92–0.98` |

**檐下听雨**

| 轨 | 角色 | 建议相对关系 |
| --- | --- | --- |
| A02 `rain_parasol` | 主环境（檐下雨） | 最响、最靠中心 |
| A01 `rain_soft` | 远雨承托 | 比 A02 明显更远 / 更轻 |
| A03 `rain_bamboo_leaf` | 细节 | 轻于 A01，偶发靠近也勿压过 A02 |
| A04 `wind_gust` | 两次短触发 | 始终偏远，不抢戏 |

旧表里的 `default_volume`（如 0.22 / 0.40）**本轮停止作为主次手段**；请全部改写成 radius（及必要时的淡入淡出）。

---

## 3. 你们要交什么（编排包）

在现有场景包旁新增一版编排修订目录即可，例如：

```text
docs/scenes/sc_rain/packages/sc_rain_v1/orchestration_v9/
docs/scenes/sc_hair/packages/sc_hair_wash_v05_review/orchestration_v12/
```

必交文件：

| 文件 | 谁填 | 内容 |
| --- | --- | --- |
| `README.md` | 素材 / 产品 | 本版听感目标、相对上一版改了什么、试听备注 |
| `source_groups.csv` | 素材 | 圆盘逻辑声源清单 |
| `clips.csv` | 素材 | 时间轴片段（出现消失、模式、淡化） |
| `position_keyframes.csv` | 素材 | 每个逻辑声源的轨迹关键帧 |
| `automation.csv` | 素材 | 淡入淡出、人声 duck（非稳态音量） |
| `change_log.md` | 素材 | 逐条变更（相对当前线上预设） |

可选：

| 文件 | 说明 |
| --- | --- |
| `phrases.csv` | 仅洗头；本轮若不改文案可复制现表并注明「文案未改」 |
| `listen_notes.md` | 外放 / 耳机主观备注 |
| 审阅用 Word/PDF | 可读附录；**不得**替代上述 CSV |

**不要提交**：新的 WAV、改名母带、替换 `master/` 文件。

---

## 4. 表格字段定义

### 4.1 `source_groups.csv`（圆盘声源）

| 字段 | 必填 | 说明 |
| --- | --- | --- |
| `group_code` | 是 | 稳定短码，如 `G_VOICE`、`G_A02` |
| `display_name` | 是 | 圆盘显示名，如「轻声陪伴」「檐下雨」 |
| `layer` | 是 | `environment` / `ambience` / `trigger` / `voice` |
| `resource_keys` | 是 | 本组会用到的素材短键，多个用 `;` 分隔 |
| `display_policy` | 是 | 见下表 |
| `notes` | 否 | 听感意图 |

`display_policy`：

| 值 | 含义 | 典型用途 |
| --- | --- | --- |
| `while_active` | 仅在有 clip 播放（含淡化）时显示 | **本轮所有官方预设声源固定使用** |
| `always_in_window` | 在场景时间窗内圆盘一直显示 | 保留值；本轮禁止使用 |
| `selected_or_active` | 选中或播放时显示 | 编辑器内部状态；本轮禁止用于官方预设 |

固定规则：

- **洗头**：全部 `voice_phrase_01`…`20` 必须同属 **一个** `group_code`（建议 `G_VOICE` / 显示名「轻声陪伴」），且使用 `while_active`；句间无 clip 时不显示
- **雨景 A04**：两次阵风同属 **一个** `group_code`（建议 `G_A04`）

### 4.2 `clips.csv`（时间轴片段）

| 字段 | 必填 | 说明 |
| --- | --- | --- |
| `clip_code` | 是 | 稳定短码，如 `C_A02`、`C_V01`、`C_A04_1` |
| `group_code` | 是 | 归属哪个圆盘声源 |
| `resource_key` | 是 | **必须**是现有短键，不得新造 |
| `start_seconds` | 是 | 场景主时钟起点（秒，可一位小数） |
| `end_seconds` | 是 | 结束时刻；必须 `> start_seconds`，且 ≤ 场景总时长 |
| `playback_mode` | 是 | `oneshot` / `loop` / `bounded_loop` |
| `fade_in_ms` | 是 | 进入淡入；无则 `0` |
| `fade_out_ms` | 是 | 退出淡出；无则 `0` |
| `crossfade_ms` | 是 | **仅 loop**；oneshot 必须 `0` |
| `phrase_id` | 条件 | 洗头人声填写既有 phrase 标识；非人声留空 |
| `intent` | 是 | 一句话说明这段在叙事里干什么 |

约束：

- `fade_in_ms + fade_out_ms` 不得超过该 clip 时长
- `crossfade_ms` 必须 `<` 母带时长的一半；常见环境 loop 用 `600–1500`
- oneshot 的 `end_seconds - start_seconds` 应 ≥ 实际音频时长（可略留尾）
- 同一 `group_code` 下可有多条 clip（人声 20 句、阵风 2 次）

### 4.3 `position_keyframes.csv`（轨迹）

| 字段 | 必填 | 说明 |
| --- | --- | --- |
| `group_code` | 是 | 轨迹作用在**组**上，不作用在单句 clip（洗头人声尤其如此） |
| `t_seconds` | 是 | 关键帧时间；同一组内必须严格递增 |
| `angle_deg` | 是 | 方位（角度制，见 §2.1） |
| `radius` | 是 | `0…1`，决定该时刻听感大小 |
| `interpolation` | 是 | 官方预设填 `linear` |
| `intent` | 否 | 如「雨势靠近」「按摩移到左侧」 |

规则：

- 相邻关键帧之间会**连续插值**（不再是到点瞬移）
- 若某段时间位置不变，仍建议在段首段尾各写一帧，或明确写「静止」
- **稳态变响 / 变轻** → 改 radius 关键帧
- **淡入淡出** → 写到 `clips.csv` / `automation.csv`，不要靠 1–2 秒内把 radius 甩到边缘冒充淡出
- 洗头人声：整组共用一条轨迹；**不要**为每一句单独写一套绕头轨迹

### 4.4 `automation.csv`（过渡类，不是主次）

| 字段 | 必填 | 说明 |
| --- | --- | --- |
| `auto_code` | 是 | 如 `AUTO_DUCK_V07` |
| `target` | 是 | `group_code` 或 `clip_code` |
| `kind` | 是 | `fade_in` / `fade_out` / `duck` / `unduck` |
| `at_seconds` | 是 | 开始时刻 |
| `duration_ms` | 是 | 过渡时长 |
| `depth_db` | 条件 | 仅 `duck`：相对衰减，洗头背景建议约 `4` |
| `notes` | 否 | |

洗头人声期间：对人声开始时相关环境组做 `duck`，在该句真实时长结束后约 **+300 ms** 再 `unduck`。

---

## 5. 场景专用清单

### 5.1 檐下听雨（`sc_rain`）

**锁定素材（勿改文件）**

| code | resource_key | 模式 |
| --- | --- | --- |
| A01 | `rain_soft` | loop |
| A02 | `rain_parasol` | loop |
| A03 | `rain_bamboo_leaf` | loop |
| A04 | `wind_gust` | oneshot（两次事件） |

**建议 SourceGroup**

| group_code | display_name | 对应 |
| --- | --- | --- |
| `G_A01` | 远雨 | A01 |
| `G_A02` | 檐下雨 | A02 |
| `G_A03` | 竹叶雨 | A03 |
| `G_A04` | 阵风 | A04 两次 |

**编排约束**

- `phrases` 保持空；禁止加人声 / 音乐 / 雷声 / 突然鸟叫
- 环境层变化宜缓：明显主次或方位变化间隔通常 **≥ 90 秒**
- A04 只保留短时两次；两次可有不同轨迹，但同属 `G_A04`
- 结尾最后约 10 秒：整体淡出或缓慢移向边缘，**禁止硬停**
- 当前线上参考窗（可改，但请在 `change_log.md` 写明）：A01 `0–620`；A02 `30–560`；A03 `220–530`；A04 `@188` 与 `@458`

### 5.2 洗头陪伴（`sc_hair`）

**锁定素材（勿改文件）**

非人声短键保持现有：`water_drip_roomtone`、`hair_wash_water_cycle`、`hair_wash_wet`、`hair_wash_foam_start`、`hair_wash_foam_rub`、`hair_wash_scalp_foam`、`hair_wash_rinse`、`hair_wash_finger_massage`、`hair_towel`。

人声：`voice_phrase_01` … `voice_phrase_20`（文案与文件不变；只可改各句 `start_seconds` / 所属组轨迹 / duck 时点）。

**建议 SourceGroup**

| group_code | display_name | 说明 |
| --- | --- | --- |
| `G_VOICE` | 轻声陪伴 | **仅此一个** voice 组，挂 20 个 clip |
| 其余 | 与现轨语义一致 | 每个非人声逻辑声源一组 |

**编排约束**

- 任意 30 秒内最多 1 句人声；句间至少约 10 秒纯声音或安静
- 人声提示通常比对应动作声早 **1–3 秒**
- 动作类用 `oneshot`；持续水声 / 揉洗用 `loop` + 合法 `crossfade_ms`
- 人声 duck ≈ **4 dB**，结束后 +300 ms 恢复
- 结尾（约 10:12–10:20）用 **淡出自动化**；若同时设计「向外移」，须在试听备注里确认不会过早无声
- 圆盘上的人声在任一句活跃时始终只有一个图标；句间无 clip 时隐藏，不要写成 20 个声源

---

## 6. 填写示例（片段）

### 6.1 `source_groups.csv`（雨景节选）

```csv
group_code,display_name,layer,resource_keys,display_policy,notes
G_A01,远雨,environment,rain_soft,while_active,全程承托，始终比檐下雨远
G_A02,檐下雨,ambience,rain_parasol,while_active,主环境；雨势变化用半径表达
G_A04,阵风,trigger,wind_gust,while_active,两次短触发，不抢戏
```

### 6.2 `clips.csv`（节选）

```csv
clip_code,group_code,resource_key,start_seconds,end_seconds,playback_mode,fade_in_ms,fade_out_ms,crossfade_ms,phrase_id,intent
C_A02,G_A02,rain_parasol,30,560,loop,8000,10000,1200,,主雨进入后缓慢建立
C_A04_1,G_A04,wind_gust,188,191.71,oneshot,0,400,0,,第一次远阵风
C_V07,G_VOICE,voice_phrase_07,178,182.15,oneshot,0,0,0,phrase_07,取洗发水前提示
```

### 6.3 `position_keyframes.csv`（节选）

```csv
group_code,t_seconds,angle_deg,radius,interpolation,intent
G_A02,30,40,0.70,linear,进入时偏右、稍远
G_A02,180,24,0.45,linear,雨势靠近、变响
G_A02,330,20,0.35,linear,最亲近段
G_A02,560,47,0.82,linear,退出前变远变轻
G_VOICE,0,0,0.38,linear,人声固定正前
```

### 6.4 `automation.csv`（洗头节选）

```csv
auto_code,target,kind,at_seconds,duration_ms,depth_db,notes
AUTO_DUCK_V07,G_A04_FOAM,duck,178,800,4,V07 起句时泡沫层让路
AUTO_UNDUCK_V07,G_A04_FOAM,unduck,182.45,800,,句尾+300ms 恢复
```

---

## 7. 提交前自检

- [ ] 未附带、未替换任何 WAV；所有 `resource_key` 均在现有清单内
- [ ] 每个 clip 都有合法 `group_code`；洗头人声 20 clip → 1 个 voice 组
- [ ] 雨景阵风 2 次 → 1 个 trigger 组
- [ ] 稳态大小只通过 `radius` 表达；淡入淡出 / duck 写在 automation 或 clip fade 字段
- [ ] 每组 `position_keyframes` 时间严格递增；`interpolation=linear`
- [ ] `angle_deg` 在 `-180…180`；`radius` 在 `0…1`
- [ ] loop 的 `crossfade_ms > 0` 且小于母带时长一半；oneshot 的 `crossfade_ms=0`
- [ ] fade 总时长不超过 clip 时长
- [ ] 雨景无 phrases；洗头人声频率与 duck 规则满足 §5.2
- [ ] `change_log.md` 写清相对当前预设（雨 v8 / 洗头 v11）改了哪些时间点与轨迹
- [ ] 至少完成一次「按表朗读时间线」的纸面走查；条件允许时附外放试听备注

---

## 8. 工程接入方式（素材无需操作，知悉即可）

1. 校验 CSV → 生成 / 更新官方 composition 或 timeline fixture
2. `ScenePlanCompiler` 编译为统一 `SceneRenderPlan`
3. 创建预览与播放页共用同一渲染结果（轨迹连续、半径增益一次施加）
4. 升 `timeline` / composition `version`；双端 fixture 哈希对齐后再试听冻结

素材侧交付验收口令：**「表能唯一描述预设；母带哈希与上一版相同。」**

---

## 9. 与旧规范的差异（速查）

| 旧习惯 | 现在 |
| --- | --- |
| `default_volume` 决定谁大声 | **radius** 决定稳态大小 |
| 一条轨 = 一个圆盘图标 = 一段音频 | **组**管圆盘；**clip** 管时间轴 |
| `set_position` 到点跳动 | 关键帧之间 **连续移动** |
| 20 句人声像 20 个声源 | **1 个**「轻声陪伴」+ 20 个 clip |
| 手写最终 `timeline.json` | 交 CSV 编排包；JSON 由工程生成 |
| 改听感就去改 WAV 增益 | 本轮 **禁止改 WAV**；用半径与自动化 |

旧文档 `docs/scene-creation-spec-v1.1.md`、各包内「场景素材包制作与交付规范」中关于**新录母带、命名、许可证、响度入包**的部分仍然有效；**本轮预设改版以本文为准**。
