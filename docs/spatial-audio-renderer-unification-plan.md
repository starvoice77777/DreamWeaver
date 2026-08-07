# 空间声场、创建页与播放页统一渲染改造计划

状态：设计冻结，等待前端大改提交并同步后实施
编写日期：2026-08-07
适用范围：iOS 创建页、播放页、本地音频引擎、场景 Composition/Timeline 契约、官方预设迁移
当前分支：codex/update-scene-presets

## 0. 为什么需要这份文档

本计划用于在上下文被压缩、任务跨会话或前端大改合并后，仍可从一个稳定真相源恢复开发。

当前阶段只允许更新本计划，不修改业务代码。必须等前端完成并提交大改、将其同步到当前开发基线、重新审查冲突文件后，才能进入实施阶段。

本计划解决以下已确认问题：

1. 创建页能够连续展示并预览轨迹，但播放页只执行离散位置跳变。
2. 创建页与播放页虽然共用 LocalPlaybackService，却使用不同的时间时钟、数据模型和轨道语义。
3. 短循环素材没有真正执行交叉淡化。
4. 原始预设的 default_volume 与产品已确认的“圆盘半径是唯一稳态音量控制”冲突。
5. 响度统一不能同时把原始场景的主次层级抹平。
6. 洗头场景需要 20 个独立人声片段，但播放圆盘上只能出现一个可统一操作的人声声源。
7. 交叉淡化所需的两个内部播放器不能变成两个 UI 声源，也不能让圆盘位置发生非预期移动。
8. 从已有场景进入创建页、创建页预览、保存后的播放页必须真正所见即所得。

## 1. 开发冻结与当前工作区快照

### 1.1 前端同步门禁

在前端大改尚未合并前：

- 不修改 DreamWeaver/Views。
- 不修改 DreamWeaver/App/AppState.swift。
- 不修改 DreamWeaver/Models。
- 不继续重构 LocalPlaybackService。
- 不提交或推送本计划之外的新业务变更。

前端通知“已停止并提交”后，实施前必须按顺序执行：

1. git status，记录本地未提交内容。
2. git fetch origin，确认前端分支和集成分支的新提交。
3. 审查前端修改文件，重点检查：
   - DreamWeaver/Views/Create/**
   - DreamWeaver/Views/Now/**
   - DreamWeaver/App/AppState.swift
   - DreamWeaver/Models/**
4. 在用户授权下，将当前后端未提交代码做有边界的提交或安全暂存；不得夹带用户自己的文档修改。
5. 先合并前端提交，再基于合并后的真实结构修订本计划中的文件落点。
6. 保留前端的布局、动画、手势、控件显隐和视觉意图；播放逻辑只能通过 AppState → Service 接线。
7. 编译和测试通过后才进入具体功能开发。

### 1.2 当前未提交内容

编写本计划时，工作区包含：

- DreamWeaver/Services/LocalPlaybackService.swift
- DreamWeaver/Services/SpatialMixMapping.swift
- DreamWeaver/Services/AudioMasteringProfile.swift（新增）
- DreamWeaver/Resources/Audio/audio_mastering_profile.json（新增）
- server/tests/test_scene_audio_assets.py
- docs/integration-remote-test-checklist.md（用户已有修改，禁止夹带、覆盖或回退）

这些修改主要属于前一阶段的播放时响度校准和半径曲线实验。前端同步后必须重新 review，不能假定它们可以原样保留。

## 2. 已确认的产品决策

以下决策是本次改造的稳定前提。

### 2.1 圆盘含义

- 角度决定声音方位。
- 半径决定用户可感知的稳态声音大小。
- 越靠中心越响，越靠边缘越安静。
- 圆盘半径不再表达真实物理距离。
- 所有送入 Apple 空间环境节点的逻辑声源保持在听者周围一米。
- Apple 空间化负责方向/HRTF；项目自己的半径曲线负责大小。

### 2.2 用户界面没有独立 volume

不得重新引入与圆盘半径并列的用户可调 volume。

但 DSP 内部仍必须存在以下互相独立的增益：

- normalizationGain：修正不同录音素材自身的响度差异。
- radialGain：由圆盘半径唯一决定的稳态用户增益。
- automationGain：淡入、淡出、人声 duck、临时静音。
- crossfadeGain：循环接缝时两个内部播放实例的互补权重。
- safetyGain：最终总线峰值安全或保护限制。

这些内部增益不能作为第二个用户音量控制暴露，也不能偷偷改变圆盘的稳态主次关系。

### 2.3 一个圆盘声源可以包含多个音频片段

- 圆盘上的一个图标代表 SourceGroup（逻辑声源组）。
- 时间轴上的每一个音频条目代表 AudioClip（音频片段）。
- 多个 AudioClip 可以引用同一个 SourceGroup。
- SourceGroup 统一拥有角度、半径、空间轨迹、用户手动覆盖状态和 UI 身份。
- AudioClip 独立拥有素材、起止时间、播放模式、循环参数、响度测量和校准增益。

洗头场景的 20 句人声必须是 20 个 AudioClip，但全部归属一个“轻声陪伴”SourceGroup。

### 2.4 UI 与内部播放实例严格分离

- SourceGroup 数量决定圆盘 UI 声源数量。
- AVAudioPlayerNode、交叉淡化 A/B 节点、预缓冲节点均是内部实现，不生成 UI 声源。
- 同一个循环素材交叉淡化时，圆盘上始终只有一个逻辑声源。
- A/B 节点共用同一个 SourceGroup 位置、半径和空间总线。
- 交叉淡化不能导致圆盘图标移动、复制或闪烁。

## 3. 当前实现的根因

### 3.1 创建页连续，播放页离散

创建页：

- 使用约 60Hz 的播放任务更新 currentTime。
- 稀疏关键帧采用 smoothstep 插值。
- 拖动录制轨迹采用线性插值。
- 每帧计算 SpatialTrajectory.position，并推送给 LocalPlaybackService.updateSource。
- 轨迹录制约 20Hz 采样，保存时做平滑和简化。

播放页：

- SceneTimelineScheduler 每 200ms 扫描一次 cue。
- set_position 到点后直接设置 AVAudioMixing.position。
- 两个位置 cue 之间没有连续求值。
- UI 的 0.45 秒动画只改变图标显示，不代表音频节点的真实连续移动。
- 当轨迹包含大量 20Hz 采样点时，5Hz scheduler 可能一次补执行多个点，形成阶梯或直接跳到批次末端。

结论：这不是 AVAudioEngine 不支持连续移动，而是播放页缺少共享轨迹求值器和高频渲染时钟。

### 3.2 数据模型把四个概念混成一个 UUID

当前 SpatialEditorSource / SoundSource 同时承担：

1. 时间轴音频片段身份。
2. 圆盘逻辑声源身份。
3. 播放器节点身份。
4. 用户手动覆盖身份。

因此：

- 20 句人声若作为 20 个可编辑片段，就容易变成 20 个圆盘声源。
- 若播放页强行共用一个 SoundSource，又无法对每句话正确绑定独立响度校准。
- 从官方 timeline 导入创建页后会拆分 clip，但重新保存时无法保留“这些 clip 属于同一个逻辑声源”的关系。

### 3.3 创建页预览不是最终播放语义

当前创建页预览会将可播放素材统一映射成 ambience，以便持续播放：

- voice/trigger 的 oneshot 语义可能在预览中变成连续或循环。
- 播放头跳转时，位置能跟着 currentTime 变化，但文件内部播放位置未必做对应的 sample-accurate seek。
- graph signature 主要由 source id 和 resourceName 组成，改变 clip 起止时间不一定重建或重新定位音频。
- 保存后的 Composition 会转为离散 cue，进一步丢失创建页实时插值语义。

### 3.4 循环元数据没有进入播放图

交付包中的 requires_engine_crossfade 和 crossfade_ms 没有完整进入 SoundSource 或播放图。

当前循环是在文件播放完成回调后重新 scheduleFile：

- 不能让下一轮提前开始。
- 没有重叠区。
- 没有 equal-power 淡入淡出。
- 可能出现接缝、鼓包、短空隙或周期感。

### 3.5 响度统一和原始层级被混为一件事

素材响度统一的目标是：

- 同类或任意素材处于圆盘同一半径时，达到可比较的主观响度。
- 修正原始文件从约 -48 LUFS 到约 -22 LUFS 的巨大差异。

原始响度层级的目标是：

- 人声、主环境、背景、动作、细节之间具有明确主次。
- 这个主次原本由 default_volume 与 radius 共同表达。

如果把所有素材统一后，又忽略 default_volume，但不重新编排 radius，原始主次就会丢失。

## 4. 目标架构

### 4.1 单一场景文档

创建页和播放页最终都应消费同一个语义模型。存储格式可以保留官方 timeline 和用户 composition 两种输入，但必须先编译成同一个 SceneRenderPlan。

~~~mermaid
flowchart LR
    O["官方 Timeline"] --> C["ScenePlanCompiler"]
    U["用户 Composition"] --> C
    C --> P["SceneRenderPlan"]
    P --> E["Shared Scene Renderer"]
    E --> A["AVAudioEngine Graph"]
    E --> S["Playback UI State"]
    E --> R["Create Preview UI State"]
~~~

禁止继续让创建页自行解释 Composition、播放页自行解释 Timeline。

### 4.2 核心模型

建议新增以下纯领域模型，最终文件名在前端合并后确认。

#### SourceGroup

建议字段：

- id：稳定 UUID。
- name / symbolName / layer。
- uiStartSeconds / uiEndSeconds。
- positionCurve：共享角度和半径轨迹。
- interpolationMode：linear / smoothstep / recordedLinear。
- manualOverridePolicy。
- displayPolicy：alwaysInWindow / whileActive / selectedOrActive。

职责：

- 对应圆盘上的一个 UI 声源。
- 拥有唯一稳态 radialGain。
- 拥有统一空间位置和自动轨迹。
- 承接用户拖动后的组级手动覆盖。

#### AudioClip

建议字段：

- id：独立 UUID。
- sourceGroupId。
- resourceKey 或 assetId。
- startSeconds / endSeconds。
- sourceOffsetSeconds。
- playbackMode：oneshot / loop / boundedLoop。
- crossfadeMs。
- fadeInMs / fadeOutMs（仅进入退出）。
- phraseId / textCueId（可选）。
- masteringProfileKey。

职责：

- 对应创建页时间轴上的独立可编辑片段。
- 独立增删、替换、移动和响度测量。
- 不直接生成圆盘 UI。

#### AutomationCurve

建议字段：

- target：sourceGroupId 或 clipId。
- parameter：position / envelope / duck。
- keyframes。
- interpolation。
- priority。

职责：

- position 只改变 SourceGroup 的角度/半径。
- envelope 只用于进入、退出、duck 和临时静音。
- steady-state 主次不得再次由 envelope 表达。

#### SceneRenderPlan

是编译后的只读执行模型，包含：

- sourceGroups。
- clips。
- position curves。
- discrete events。
- fade/duck curves。
- 预计算 loudness compensation。
- 预计算 loop scheduling。
- scene duration 和 renderer version。

## 5. 统一播放时钟与连续轨迹

### 5.1 时钟职责拆分

不能简单把现有 Timer 从 200ms 改成 16ms。需要拆分：

- 离散事件：clip start/stop、enable/disable、phrase trigger。
- 连续参数：angle、radius、fade、duck、crossfade。
- UI 刷新：圆盘显示和时间轴游标。

推荐：

1. clip 的开始与停止尽量使用 AVAudioTime 提前做 sample-accurate 调度。
2. 连续空间参数由共享 SceneRenderer 以 30–60Hz 求值。
3. UI 读取 RendererState，不再独立做一套可能与音频不一致的动画。
4. 使用单调时钟，pause/resume 后不漂移。
5. scheduler 的 200ms timer 只可保留为非精密离散事件的兜底，不再负责连续运动。

### 5.2 轨迹插值规范

官方预设：

- 相邻关键帧默认 linear。
- angle 使用最短角差插值，避免跨越 ±π 时绕远路。
- radius 线性插值或根据产品最终确认使用 smoothstep。
- 洗头和雨景交付文档中的 30–60 秒移动必须在完整时间段连续发生。

用户创建：

- 手工稀疏点默认 smoothstep，保持当前创建页手感。
- 手势录制样本默认 recordedLinear，保留速度变化。
- 保存时保留 interpolationMode，不能只保存终点。
- 服务端不 densify；客户端运行时求值。

### 5.3 UI 一致性

- 播放页圆盘显示 Renderer 当前真实位置。
- 不再使用固定 0.45 秒 UI 动画掩盖音频跳变。
- UI 可对 RendererState 做轻微显示平滑，但不能更改时间或目标位置。
- reduce motion 只能改变视觉过渡，不能禁用或改变音频空间轨迹。

## 6. 圆盘增益与响度层级

### 6.1 当前圆盘增益

当前实验公式：

G(r) = 1 - 0.99 × r³

其中：

- r = 0 时 G = 1，即 0dB。
- r = 1 时 G = 0.01，即约 -40dB。

近似映射：

| radius | radial gain |
|---:|---:|
| 0.38 | -0.5dB |
| 0.62 | -2.2dB |
| 0.80 | -6.1dB |
| 0.85 | -8.1dB |
| 0.90 | -11.1dB |
| 0.95 | -16.4dB |
| 1.00 | -40dB |

正式实施前必须做一次曲线评审。当前曲线在圆盘内侧变化较小，约 -8dB 至 -20dB 的大量可用层级被压缩在 0.85–0.97，可能影响 UI 精确拖动。

候选方向：

- 保留当前三次曲线，但为外圈提供更精细的拖动映射或吸附档位。
- 改用 dB 空间曲线，使圆盘半径更均匀对应听感变化。
- 无论选择哪种曲线，边缘必须接近无声，且移出圆盘不产生明显音量跳变。

曲线一旦定稿，必须作为前后端共享规范写入文档和测试，不能再在预设里手工“压半径上限”补偿旧算法。

### 6.2 最终增益链

每个 clip 的信号链：

finalSample =
rawSample
× normalizationGain(clip)
× crossfadeGain(internal playback instance)
× automationGain(clip/group)
× radialGain(sourceGroup.radius)
× safetyGain(master bus)

顺序要求：

1. 素材响度校准在 clip 级发生。
2. 交叉淡化在同一 clip 的 A/B 内部实例之间发生。
3. 淡入、淡出、duck 在 clip/group 自动化层发生。
4. 圆盘半径增益在 SourceGroup 总线上只应用一次。
5. 两个交叉淡化节点不能各自重复应用 radialGain。

### 6.3 “没有 volume”的迁移规则

旧数据中的音量变化需要分类：

#### 转换为圆盘半径

- 非零稳态音量之间的艺术主次差异。
- 场景初始主层、背景层、细节层的默认比例。
- 雨势“更近、更明显”等确实代表用户可感知大小的长期变化。

转换方式：

- 先按素材响度统一到共同基线。
- 将旧 default_volume、原半径和交付文档定义的层级合成为目标相对 dB。
- 使用最终半径曲线的反函数得到新 radius。
- 保留 angle。
- 生成迁移报告，由设备试听确认，不直接静默写回。

#### 保留为内部 automationGain

- 从 0 淡入。
- 淡出至 0。
- 人声出现时背景 duck。
- 人声结束后的恢复。
- 临时静音。
- 循环交叉淡化。

原因：这些是时间过渡，不是稳态空间主次。若强行通过移动圆盘实现，会让 UI 图标来回移动并破坏空间轨迹。

### 6.4 原始预设层级迁移

#### 洗头陪伴

交付目标：

- 人声 0dB 参考。
- 环境低约 14–20dB。
- 动作低约 8–12dB。
- 近耳触感低约 6–10dB。
- 人声期间背景额外 duck 约 4dB。

迁移步骤：

1. 20 句人声逐句校准到共同目标。
2. 人声 SourceGroup 使用统一位置曲线，初始建议保留正前方。
3. 环境、动作和触感不再依赖 default_volume，按目标相对 dB 计算 radius。
4. 人声 duck 保留为 automationGain，不移动任何圆盘图标。
5. 10:12–10:20 的最终退出保留为 8 秒 automation fade，同时可保留作者明确设计的向外移动。
6. 若 fade 与向外移动同时存在，应在验收中确认两者叠乘不会过早无声。

#### 檐下听雨

交付目标：

- A02 檐下雨是主环境。
- A01 远雨持续承托。
- A03 竹叶雨是细节。
- A04 阵风仅两次短时变化，不抢注意。

迁移步骤：

1. 四个素材先统一素材基线。
2. 用 radius 重新建立 A02 > A01 > A03/A04 的可感知层级。
3. 恢复交付包的完整关键帧语义，不继续使用为旧衰减算法设置的 0.77/0.78/0.80 人工上限。
4. A02 的长期雨势变化优先转换为 radius curve。
5. A01/A02/A03 的进入退出仍使用 automation fade。
6. A04 两次事件可以有不同内部 event automation，但圆盘上始终是同一个“阵风”SourceGroup。

## 7. 循环交叉淡化

### 7.1 算法

每个需要 crossfade 的 loop clip 使用两个内部播放实例 A/B：

1. A 从素材起点开始播放。
2. 距离 A 结束 crossfadeMs 时，B 从素材起点开始。
3. A 使用 equal-power fade out。
4. B 使用 equal-power fade in。
5. A 结束后回收或准备下一轮。
6. 下一轮 B/A 交换角色。

推荐权重：

- gainA(t) = cos(πt/2)
- gainB(t) = sin(πt/2)
- t ∈ [0, 1]

### 7.2 音频图

~~~mermaid
flowchart LR
    A["Loop Player A"] --> GA["Crossfade Gain A"]
    B["Loop Player B"] --> GB["Crossfade Gain B"]
    GA --> GM["SourceGroup Mixer"]
    GB --> GM
    GM --> RG["Single Radial Gain"]
    RG --> SP["Single Spatial Source"]
    SP --> ENV["AVAudioEnvironmentNode"]
~~~

关键约束：

- A/B 不是 SourceGroup。
- A/B 不出现在圆盘。
- A/B 位置始终来自同一个 SourceGroup。
- radialGain 只在合并后的 SourceGroup 总线上应用一次。
- 交叉淡化期间 SourceGroup UI 不移动。
- 若交叉淡化总能量保持稳定，UI 不需要显示任何音量变化。
- 如需反馈循环状态，只能使用非位置型的轻量视觉状态，不得生成第二个图标。

### 7.3 参数与降级

- crossfadeMs 必须大于 0 且小于素材时长的一半。
- 非法值在编译 RenderPlan 时返回可定位错误。
- 缺少交叉淡化能力时，正式预设不得静默硬循环。
- 可选降级：使用交付包 demo/ 中的长预渲染版本。
- 不得把场景 fadeIn/fadeOut 当作循环 crossfade 的替代。

## 8. 洗头人声：20 个片段、1 个逻辑声源

### 8.1 数据关系

固定一个 Voice SourceGroup：

- group id 使用稳定官方人声组 UUID，或在新 schema 中明确 voice-group id。
- name = 轻声陪伴。
- angle/radius/positionCurve 为组级属性。
- manual override 作用于整个 group。
- UI 时间窗口默认从第一句开始至最后一句结束；句间静音时图标仍可保持显示，以获得“像一条长素材”的操作感。

20 个 Voice AudioClip：

- clip id 独立，优先复用 phrase id。
- 分别引用 voice_phrase_01 至 voice_phrase_20。
- 每句保留独立 start/end。
- 每句独立 normalizationGain。
- 每句可以单独替换、删除、移动和试听。
- text cue 与对应 clip 关联。

### 8.2 播放页

- 圆盘上只显示一个“轻声陪伴”图标。
- 拖动图标立即影响正在播放的人声，并影响后续全部人声 clip。
- 用户手动拖动后，跳过该 SourceGroup 后续官方位置自动化，但不能跳过人声 clip 的播放时间。
- 句间没有音频时，图标可显示为静默/待机态，但不能消失后又以新 UUID 出现。
- 删除某一句不改变 SourceGroup 身份。
- 删除全部人声 clip 后才移除 SourceGroup。

### 8.3 创建页

- 时间轴显示 20 个独立 clip，可单独选择、增删、换素材、移动时间。
- 圆盘只显示 Voice SourceGroup。
- 选中任一句时，圆盘仍选中同一个 Voice SourceGroup。
- 拖动圆盘修改组级轨迹，不只修改当前句的临时位置。
- 如果未来需要某一句特殊位置，必须显式设计 clip-level spatial override；本次默认不支持，避免破坏统一操作。
- 当前“场景只能有一个 voice source”的限制要改为“可以有多个 voice clip，但默认只有一个 voice SourceGroup”。

### 8.4 响度校准

当前共用播放器 EQ 只按首次绑定资源初始化的问题必须修复。

目标：

- 调度每个 clip 时按其实际 resourceKey 获取 compensation。
- 不允许 voice_phrase_02 至 20 继续沿用 voice_phrase_01 的 gain。
- 每句校准后目标综合响度偏差建议控制在 ±1 LUFS；受真峰值限制的素材记录为 peak-limited。
- 片段校准位于 Voice SourceGroup 之前，组级圆盘增益随后统一应用。
- 原音频文件保持不改写，继续保留交付包哈希。

实现可选：

- 每个活跃 clip 独立 AVAudioUnitEQ。
- 或复用 node pool，但在 schedule 前原子更新与实际 clip 对应的 mastering gain。
- 如存在重叠人声，必须为重叠 clip 使用独立节点，不能共用一个会被动态改 gain 的节点。

## 9. API 与持久化契约

### 9.1 推荐 schema

建议新增 scene_composition_v2，避免在 v1 的 track 概念上继续叠加歧义。

示意：

~~~json
{
  "schema": "scene_composition_v2",
  "version": 1,
  "duration_seconds": 620,
  "source_groups": [
    {
      "id": "voice-group-uuid",
      "name": "轻声陪伴",
      "layer": "voice",
      "display_policy": "always_in_window",
      "position_keyframes": [
        {
          "t": 0,
          "angle": 0,
          "radius": 0.38,
          "interpolation": "linear"
        }
      ]
    }
  ],
  "clips": [
    {
      "id": "phrase-01-uuid",
      "source_group_id": "voice-group-uuid",
      "resource_key": "voice_phrase_01",
      "start_seconds": 3,
      "end_seconds": 7.1,
      "playback_mode": "oneshot",
      "crossfade_ms": 0
    }
  ]
}
~~~

### 9.2 兼容策略

- 服务端在过渡期同时接受 v1 和 v2。
- v1 读取时按 track 生成一对一 SourceGroup + AudioClip。
- 官方 timeline 通过编译器映射为 SourceGroup/AudioClip，不要求立即改变现有 GET endpoint。
- 旧客户端继续接收 timeline-contract-v1。
- 新客户端优先使用 composition v2；无 v2 时编译 timeline v1。
- v2 保存后不得反向降级覆盖原始 v1 文档。
- 私人场景 draft/saved 继续使用事务快照。

### 9.3 Timeline 编译规则

- play_phrase：生成一个 voice AudioClip，绑定共享 Voice SourceGroup。
- play_oneshot：生成 oneshot AudioClip。
- play/pause/enable/disable：生成 clip 生命周期或离散事件。
- set_position：生成 SourceGroup position keyframe。
- set_volume/set_envelope：
  - 稳态艺术比例迁移为 radius keyframe。
  - fade/duck/静音保留为 automation curve。
- crossfade_ms：进入 loop clip。
- event_id、phrase_id、原 track id 保留在 metadata，便于回溯和调试。

## 10. 代码结构建议

具体文件名在前端同步后确认，建议按职责拆分：

### 10.1 纯模型/算法

- DreamWeaver/Models/SceneSourceGroup.swift
- DreamWeaver/Models/SceneAudioClip.swift
- DreamWeaver/Models/SceneRenderPlan.swift
- DreamWeaver/Services/SpatialTrajectoryEvaluator.swift
- DreamWeaver/Services/RadialGainCurve.swift
- DreamWeaver/Services/ScenePlanCompiler.swift

要求：

- 不依赖 SwiftUI。
- 可独立单元测试。
- 注意 SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor。
- 纯值类型算法应明确 nonisolated 或放在不会引发 MainActor Codable 问题的边界。

### 10.2 渲染器

- DreamWeaver/Services/SceneRenderer.swift
- DreamWeaver/Services/AudioGraphController.swift
- DreamWeaver/Services/LoopCrossfadeController.swift
- DreamWeaver/Services/ClipScheduler.swift

职责：

- SceneRenderer：共享时钟和状态求值。
- ClipScheduler：sample-accurate clip 调度。
- LoopCrossfadeController：A/B 双节点循环。
- AudioGraphController：SourceGroup 总线、空间节点、attach/detach。
- LocalPlaybackService：保留为对 AppState 的门面，逐步瘦身，不继续承载全部细节。

### 10.3 创建页适配

前端文件属于高冲突区，必须在前端大改同步后最小修改：

- SpatialTimelineViewModel 不再自行维护第二套播放循环。
- 创建预览调用 SceneRenderer。
- SpatialEditorSource 拆分为 SourceGroup view model 与 AudioClip row model。
- 时间轴渲染 clip，圆盘渲染 group。
- 保留前端最新布局、手势、动画和可访问性实现。

### 10.4 播放页适配

- SoundMixCircleEditor 只消费 SourceGroup UI state。
- AppState 手动拖动按 group id 调用 renderer override。
- onTimelineSourceChange 替换为 RendererState 订阅，或提供兼容适配层。
- mix palette、idle return、控件显隐等前端逻辑不得被删除。

## 11. 分阶段实施计划

### 阶段 0：同步与重新审计

目标：获得前端大改后的稳定基线。

- 合并前端提交。
- 重新读取 .cursor/rules。
- 对比本计划涉及的全部文件。
- 确认前端是否已改变创建页模型、时间轴、圆盘或 AppState 接口。
- 更新本计划中的实际文件清单。
- 处理当前响度实验代码与前端代码的冲突。
- 输出一份“保留前端 / 保留播放服务 / 需要手工拼合”的冲突清单。

完成条件：

- 工作区干净或已有明确的、有边界的提交。
- Xcode 基线可编译。
- 后端测试通过。
- 前端确认停止修改共享危险文件。

### 阶段 1：纯领域模型与算法

目标：先建立不触碰 UI 的稳定核心。

- 新增 SourceGroup、AudioClip、AutomationCurve、SceneRenderPlan。
- 抽出共享 SpatialTrajectoryEvaluator。
- 抽出 RadialGainCurve 及反函数。
- 定义 timeline/composition 编译规则。
- 为官方洗头/雨景生成 RenderPlan 快照测试。

完成条件：

- 创建输入和官方输入都能编译。
- 20 句人声属于同一 group、20 个 clip。
- 雨景四个 group、正确 clip/event 数量。
- 位置关键帧和插值模式不丢失。

### 阶段 2：共享时钟与连续空间渲染

目标：播放页先实现真实连续移动。

- 新增 SceneRenderer 单调时钟。
- 连续参数 30–60Hz 求值。
- UI 与音频共享 RendererState。
- pause/resume/seek 不漂移。
- 移除播放页用 UI 动画掩盖位置跳变的依赖。

完成条件：

- 60 秒位置移动无可辨跳步。
- 创建预览和播放页在相同时间点输出相同 angle/radius。
- 录制轨迹保存后重播路径误差在约定容差内。

### 阶段 3：SourceGroup 音频图

目标：建立“一个 UI 声源，多 clip/多节点”的音频结构。

- 每个 SourceGroup 建立统一 group mixer/spatial source。
- clip player 先做独立素材校准，再汇入 group。
- radialGain 只应用一次。
- clip attach/detach 不改变 group UI 身份。
- 支持多个 clip 同时或顺序播放。

完成条件：

- 20 句人声逐句使用自己的补偿值。
- 播放圆盘只有一个人声图标。
- 拖动人声 group 影响当前及后续句子。
- 句间静音不重建或替换 UI identity。

### 阶段 4：循环交叉淡化

目标：满足交付包 loop 验收要求。

- 实现 A/B 双节点。
- equal-power crossfade。
- 使用 clip.crossfadeMs。
- 支持停止、暂停、seek、场景退出时取消已排程节点。
- 节点回收无泄漏。

完成条件：

- A01/A02/A03 及洗头四条 loop 连续播放至少两分钟。
- 无明显断点、鼓包、掉音、短空隙。
- 圆盘不出现重复图标。
- 交叉淡化期间 group 位置不移动。

### 阶段 5：创建页统一

目标：创建页真正所见即所得。

- 创建页改用 SceneRenderer。
- 时间轴显示 AudioClip。
- 圆盘显示 SourceGroup。
- 20 句人声可独立编辑但共用一个 group。
- oneshot/loop 在预览和最终播放一致。
- seek 时按素材 offset 正确定位或重新调度。

完成条件：

- 同一 composition 在创建预览和播放页的事件、位置、响度一致。
- 从已有场景创建后，音频起止和轨迹完整导入。
- 保存、关闭、重开后 group/clip 关系不丢失。

### 阶段 6：官方预设迁移

目标：将旧 volume + radius 编排迁移为新半径语义。

- 生成洗头和雨景迁移候选。
- 还原此前因旧衰减曲线设置的半径上限。
- 以文档层级生成新 radius。
- 保留 fade/duck/crossfade 自动化。
- 更新时间线版本和 fixture。
- 后端 reseed 幂等升级。

完成条件：

- 素材哈希仍与交付母带一致。
- 官方时间点和 clip 数量不变。
- 主次关系符合场景文档。
- 预设边缘退出接近无声。

### 阶段 7：清理兼容层

目标：删除旧的重复执行路径。

- 创建页不再独立维护音频播放循环。
- 播放页不再直接把 set_position 当成最终渲染动作。
- 清理仅用于旧 volume 的字段和注释。
- 保留 v1 数据读取迁移器。
- 更新契约和协作文档。

完成条件：

- 只有一个共享 renderer。
- 没有第二套轨迹插值。
- 没有 UI 直接操作 AVAudioPlayerNode。
- 没有旧字段被静默忽略后造成听感变化。

## 12. 测试计划

### 12.1 纯算法测试

- radial gain：中心、关键半径、边缘值。
- radial inverse：gain → radius → gain 往返误差。
- angle shortest-path 插值。
- linear/smoothstep/recordedLinear 插值。
- pause/resume/seek 时钟。
- automation 曲线边界。
- equal-power crossfade：任意 t 时 gainA² + gainB² ≈ 1。
- crossfadeMs 参数边界。

### 12.2 RenderPlan 编译测试

洗头：

- 1 个 voice SourceGroup。
- 20 个 voice AudioClip。
- 9 个非人声素材组/片段按真实事件映射。
- 138 个 cue 的语义不丢失。
- V20 604 秒触发，611.85 秒恢复，612 秒开始最终退出。
- 所有 phrase 绑定实际 resource key。

雨景：

- 4 个 SourceGroup。
- A04 是一个 group、两个 oneshot clip/event。
- A01 0–620 秒。
- A02 30–560 秒。
- A03 220–530 秒。
- A04 188 秒和 458 秒。
- 26 个位置关键帧全部存在并具有 interpolation。

### 12.3 音频图测试

- 每个 resource 使用正确 normalizationGain。
- voice phrase 2–20 不沿用 phrase 1 的 gain。
- node attach/detach 数量稳定。
- seek 后无重复播放。
- stop 后无延迟 completion 回调重新启用旧 clip。
- 多 clip 同 group 时 radialGain 只应用一次。
- crossfade A/B 不产生两个 group。
- 一条素材缺失时其他 group 继续播放。

### 12.4 后端/API 测试

- composition v1 兼容读取。
- composition v2 校验。
- source_group_id 引用完整。
- clip 时间窗口合法。
- keyframe 时间严格升序。
- interpolation 枚举合法。
- crossfadeMs 合法。
- draft/save/copy 不丢 group/clip。
- 官方 reseed 幂等。
- timeline v1 老客户端仍可读取。

### 12.5 UI 测试

- 圆盘只显示 SourceGroup。
- 时间轴显示 AudioClip。
- 20 句人声时间轴有 20 条，圆盘只有 1 个。
- 交叉淡化期间图标不复制、不移动。
- clip 进入退出不改变 group identity。
- 拖动 group 后所有后续 clip 继承位置。
- 手动覆盖只跳过 group 的后续位置自动化，不跳过 clip 播放。
- 删除单句后 group 保留。
- 删除最后一句后 group 移除。
- 创建页与播放页同一时刻位置一致。

### 12.6 设备试听

必须在 Mac/Xcode 和真实 iPhone 完成：

- 手机外放。
- 普通耳机。
- 支持空间音频的耳机（如可用）。
- 不同系统音量档位。
- 多轨叠加峰值检查。
- 后台/前台切换。
- 来电或音频会话中断恢复。

## 13. 两个官方预设的最终验收

### 13.1 洗头陪伴

- 开场不会一次显示大量尚未进入的独立圆盘声源。
- 20 句人声均能听见，逐句响度一致且无削波。
- 圆盘只有一个“轻声陪伴”group。
- 人声出现时背景约 duck 4dB，结束 300ms 后恢复。
- 水流、泡沫、冲洗、毛巾和滴水按时间进入退出。
- 8 秒以上轨迹连续移动，无跳点、快速绕头。
- 四条 loop 连续两分钟无明显接缝。
- 10:12–10:20 平滑退出，无硬停。
- 创建页导入后可以看到 20 个独立人声 clip，并能单独增删。

### 13.2 檐下听雨

- 无任何人声或文本。
- A02 为主环境，A01 稳定承托，A03 只补充细节。
- A04 只在 3:08 和 7:38 出现，不循环、不抢注意。
- A01/A02/A03 循环两分钟无接缝。
- 位置在 30–60 秒区间连续移动。
- 退出关键点无硬切。
- 圆盘上的四个 group 身份稳定，不因循环产生副本。

## 14. 性能与安全边界

- 连续位置更新目标 30–60Hz；根据设备性能降级不得低于可接受平滑阈值。
- 音频 clip 节点按活跃窗口惰性创建，不一次 attach 全场全部节点。
- voice 20 句可使用 node pool，但逻辑 clip 必须独立。
- 每个 loop group 常驻最多两个交叉淡化播放节点。
- 所有 completion callback 使用 generation token，避免旧回调操作新场景。
- stop/scene switch 时取消 scheduler、曲线任务、节点排程和 UI state。
- 每源 -1dBTP 不能保证多轨总线不削波；必须监控最终总线峰值。
- 如加入 master safety limiter，只作为保护，不参与艺术主次。
- Swift 6 Sendable/MainActor 警告必须视为错误处理。

## 15. 可观测性与调试

开发构建建议提供可关闭的诊断输出：

- scene renderer version。
- 当前 scene time。
- active source groups。
- active clips。
- clip 实际 resource key。
- normalization gain。
- radius / radial dB。
- automation gain。
- crossfade A/B progress。
- 最终 group gain。
- node attach/detach 数量。
- missed scheduling deadline。

诊断信息不得在正式 UI 暴露，也不得记录用户私密音频内容。

## 16. 风险与控制

### 高风险共享文件

- DreamWeaver/App/AppState.swift
- DreamWeaver/Models/**
- DreamWeaver/Views/Now/SoundMixCircleEditor.swift
- DreamWeaver/Views/Now/NowView.swift
- DreamWeaver/Views/Create/**

控制措施：

- 前端同步前不修改。
- 修改前通知前端暂停同文件。
- UI 冲突保留前端意图。
- 播放/Service 冲突保留后端意图。
- AppState 手工拼合，不整文件选择单方版本。

### 数据迁移风险

- v1 track UUID 被 UI 当成 source UUID。
- 官方人声当前共用 track id，创建导入后可能拆成 clip id。
- 私人场景可能保存旧 volume 或旧 radius。
- 同名 resource 可能具有不同扩展名。

控制措施：

- 引入明确 sourceGroupId。
- 所有迁移可重复、幂等。
- 保存原文档版本和迁移版本。
- 提供迁移前后快照测试。
- 不自动覆盖用户已手动编辑的私人场景。

### 听感风险

- 响度统一后背景可能过响。
- 半径迁移后大量 group 挤在外圈。
- fade 与向外移动叠乘导致过早无声。
- 多轨叠加可能削波。
- equal-power crossfade 对高度相关素材可能产生鼓包。

控制措施：

- 自动计算只是候选，最终必须实机试听。
- 对高度相关 loop 允许选择 linear 或自定义 crossfade curve，但默认 equal-power。
- 记录 group 最终增益与总线峰值。
- 两个官方场景分别建立金标试听清单。

## 17. 本轮明确不做的事

- 不在前端提交前修改业务代码。
- 不重新编码或覆盖交付音频母带。
- 不把 20 句人声合并成一个新长 WAV。
- 不通过复制 UI 图标表达内部播放节点。
- 不把 crossfade 伪装成圆盘移动。
- 不重新引入用户可调 volume。
- 不用 UI 动画替代音频轨迹插值。
- 不把短循环 demo 文件静默替换为正式母带。
- 不在 Windows 上声称已完成 iOS 编译或实机听感验收。

## 18. 实施完成定义

只有同时满足以下条件，任务才可判定完成：

1. 前端大改已同步并保留。
2. 创建页和播放页共用 SceneRenderer。
3. 同一 SceneRenderPlan 在两页输出一致。
4. 连续轨迹真实作用于音频，不只是 UI。
5. 循环素材执行真正交叉淡化。
6. 交叉淡化不产生额外 UI 声源。
7. 半径是唯一用户稳态响度控制。
8. 淡入淡出、duck、crossfade 被明确限定为内部自动化。
9. 20 句人声是独立 clip、独立校准、单一 SourceGroup。
10. 创建页可单独增删 20 句 clip，圆盘统一操作。
11. 洗头和雨景达到各自验收清单。
12. 原始母带哈希不变。
13. 后端测试、Swift 编译、设备试听全部通过。
14. 代码 review 无高优先级问题。
15. 提交、推送和 PR 按协作规则完成。

## 19. 恢复开发时的第一条指令

当用户确认前端已提交并要求继续时，首先执行：

1. 阅读本文件全文。
2. git status / branch / log / fetch。
3. 检查前端提交涉及的共享文件。
4. 保护 docs/integration-remote-test-checklist.md 的用户修改。
5. 审查当前未提交响度代码，不假定正确。
6. 先合并前端，再更新本计划的阶段 0 结论。
7. 从阶段 1 的纯模型和算法开始，不直接从 UI 或 LocalPlaybackService 大改起步。
