# v1.2 单独音频入库（切片 1）

输入为 `backend_handoff_v1_2/audio_asset_index.csv` 中的 57 个 `source_library` 条目。
导入器校验全部 96 条索引的路径、大小和 SHA-256，原始交接包不修改、不提交。
切片 1 建立 App 资源及索引；切片 2 接入手动编辑器。场景时间线和后端 catalog 待后续切片接入。

## 处理与追溯

- 4 个文件与既有雨声/阵风母带哈希相同，复用原资源；其余 53 个编码为 48 kHz 双声道 AAC 160 kbps。
- 使用固定增益，目标 -24 LUFS、编码前峰值上限 -3.5 dBTP；编码后重新测量；AAC 峰值超过 -3 dBTP 时降低增益并从原文件重编码，最多三次，仍超限则拒绝导入。
- 保留原时长，不裁剪、不变速、不制作伪循环。后续播放需分别指定单次/循环模式和交叉淡化。
- `handoff_audio_catalog.json` 记录中文名、分类、原文件哈希、输出哈希、资源键及场景包资源键关联。
- 新增音频的实测响度写入 `audio_mastering_profile.json`，沿用现有播放增益逻辑。
- 索引中的 `assetStatus=qc_pending`、`licenseStatus=unreviewed` 是保守的入库状态，不代表场景授权结论。
  交接包原有的逐场景授权记录仍是后续审核依据，文件复用也不表示新用途已获授权。

## 开发试听范围

新增文件使用 `handoff_` 前缀，App target 的 Release 配置通过 `EXCLUDED_SOURCE_FILE_NAMES` 排除 `handoff_*`。
设置语义参见 [Apple Build settings reference](https://developer.apple.com/documentation/xcode/build-settings-reference)。
索引明确 `releaseReady=false`，后续素材选择入口必须仅在 Debug 加载。
口腔、刮擦、金属等敏感素材保留在索引中，不能因本次处理自动进入预设场景。
Windows 检查不替代 Xcode Release 产物检查、耳机/外放试听及循环接缝验收。

## 复现

在仓库根目录运行（使用已安装 `server[dev]` 的 Python，含 `imageio-ffmpeg`）：

```powershell
python scripts/import_handoff_audio.py <交接包绝对路径>
python -m pytest -c server/pyproject.toml server/tests/test_handoff_audio.py server/tests/test_scene_audio_assets.py
```

AAC 输出哈希可能随 FFmpeg 版本变化，更新后应重新审查索引与响度记录。

## 切片 2：手动编辑器接线

Debug 构建的手动空间编辑器素材列表追加全部 57 项。通过索引中的真实资源键播放，
保存/重新打开时优先精确匹配资源，避免把阵风、纸张等映射成其他声音。
不分配虚假的后端素材 UUID；本次不开放 AI 生成，也不改变现有 AI 推荐列表。

- 13 个有场景轨道依据的循环素材，按交接包 `tracks.csv` 的 500–1200 ms 参数交叉淡化，初始片段 30 秒。
- 其余 44 项默认单次播放，初始片段使用实际音频时长（包括 160 秒棉棒片段），不按文件名猜测循环。
- 素材分类只提供手动编辑器的初始图层，后续官方预设仍以各自轨道的角色为准。
- Release 不加载该索引；新资源的打包排除沿用切片 1 的配置。
- 切片 2 没有替换官方场景时间线或更新数据库；后续进度见下。

`HandoffAudioCatalogTests` 覆盖资源解析、单次时长、循环参数、重复添加与保存回读。
现有 `ios-ai-tests` 工作流已加入该测试套件及 `SceneCompositionMapperTests`；需要 PR 的 macOS CI
或本机 Xcode 执行，Windows 无法运行这些 Swift 测试。实机需检查素材添加、试听、保存和重新打开。

## 切片 3：新版檐下听雨

源包 v11 转换为应用内部修订号 12（旧雨景已使用修订号 11）。
`scripts/import_rain_handoff.py <sc_rain_v1包路径>` 校验四条母带与 Bundle 哈希一致，
保留源 cue 顺序及所有位置关键帧，映射稳定声源 ID，并生成两份一致的本地/后端 fixture。
导入器固定校验已审查的源时间线 SHA-256 `b11c88c…8749e`，因此修改 timeline 或只更新
包内旧 `package_manifest.csv` 都不能覆盖正式 fixture；时间线变更必须先更新代码中的可信哈希并重新审查。
两次阵风的结束时间按真实时长补上 pause/disable；原始音频不重新编码。
fixture 中 `_handoff` 保存源文件哈希、音频哈希及 `release_ready=false`，API 的字段形状不变。
后端旧库升级与新版数据、重复读取、客户端编译出的混音增益均有对应测试。
其余四个场景仍待后续切片；iOS CI 与外放/耳机实测尚需执行。

## 切片 4：本地炉边静夜预设

Debug 的 `LocalContentService` 用交接包 `sc_fire_v01_review` v4 替换旧「炉边低语」，
沿用场景 ID、视觉样式与收藏/收听记录，五条轨道使用交接包稳定 ID 和已入库 AAC。
`scripts/import_fire_handoff.py <包路径>` 校验母带、source_map 与 AAC 哈希，保留审核状态和六份源文件哈希。
导入器同时固定校验已审查包的六个输入文件 SHA-256；任何时间线或元数据变更都必须先更新
代码中的可信哈希清单并重新审查，不能通过同步修改包内清单直接覆盖应用 fixture。
生成的 `Resources/Mock/handoff_fireplace_v4.json` 含场景、轨道与时间线；Release 沿用 `handoff_*` 排除规则。

- 以事件为准：房间底声 0–620 秒，炉火 10–620 秒（轨道概览中的 0 秒不覆盖事件）。
- 木柴在 75、168、278、389、505 秒单次播放，按交接时长补充结束边界；不循环。
- 两条循环分别使用 500/1000 ms 交叉淡化，保留渐入、570 秒收弱、610–620 秒渐出。
- 初始 envelope 为 1，保留原始事件增益，避免编译器把低音量归一化为满量。

未修改 API、数据库或远端 catalog；远端模式尚未替换炉火，后端同步另作切片。
Swift 回归测试已加入现有 `BundledTimelineContractTests` CI 选择范围，需 Mac/Xcode 执行。
仍需外放/耳机试听及至少两分钟循环接缝验收；QC、授权和 release blockers 未被本次接线解除。

## 切片 5：炉火远端联调

后端使用随 `server/app/fixtures` 打包的同一份炉火 fixture，不依赖原交接目录或 iOS 工程路径。
在 `development`、`local` 或 `test` 环境，设置 `DW_ENABLE_HANDOFF_REVIEW_PRESETS=true` 并重启 API 后，
场景列表、详情与时间线会返回新版炉火；默认值为 false。生产和其他环境即使设置 true 也不会启用。
联调客户端须使用包含 handoff 音频的新版 Debug 构建，Release 不包含这些音频。

旧数据库首次读取时，在同一事务中替换炉火轨道与时间线；无需清库或 Alembic 迁移。
关闭开关并重启后，下一次场景读取会恢复旧炉火目录和空时间线，移除官方场景中的 review 轨道。
这里只更新固定 ID 的官方炉火场景，用户自己的混音/场景副本不受此迁移影响。
API 字段未改；`initial_envelope`、`resource_key`、`loop` 与 Bundle fixture 对齐，循环交叉淡化由新版客户端恢复。
开关切换时应重启客户端以清除当前会话已缓存的时间线；本机 `.env` 未由本切片修改。

## 切片 6：雾海缓潮可复现导入

`scripts/import_fire_handoff.py <sc_mist_v01_review包路径>` 现在按包内 `scene_id` 选择炉火或雾海配置。
雾海导入固定校验六个已审查输入文件的 SHA-256，再校验母带、`source_map` 与应用 AAC 哈希；
时间线或元数据变更必须先更新代码中的可信哈希并重新审查。导入器生成与 App 完全一致的
`handoff_mist_v4.json` 后端 fixture，不改变当前远端目录；后端 API 接线留在下一切片。

- 海底、海风从 0 秒持续到 600 秒；岸边水声 0–330 秒，水拍船身 300–600 秒，交接淡化 30 秒。
- 轨道摘要列出六次单次触发，但 cues 还包含 465 秒海鸟声；以 cues 为准保留七次触发，并按 5 秒母带时长补出 470 秒结束边界。
- 来源包仍为 `release_ready=false`；六条素材 QC、许可证、循环接缝、空间移动和突发感审核仍是发布阻断项。
- 便携后端测试不依赖未跟踪的交接目录，覆盖可信哈希、fixture 一致性、真实层级、播放窗口和交接行为。

原始交接包未修改，炉火导入结果保持不变。本切片不修改 API、数据库、环境配置或 App 运行时代码。

## 切片 7：雾海缓潮远端联调

`DW_ENABLE_HANDOFF_REVIEW_PRESETS` 现在同时控制炉火与雾海场景，默认仍为 false，允许环境不变。
启用后，原「星期天」的稳定场景 ID 返回「雾海缓潮」、六条轨道和 600 秒完整时间线，
包含 465 秒海鸟事件，与本地 fixture 一致；关闭后恢复旧名称、轨道和空时间线。
两场景分别缓存并按各自 ID 升级，不会相互覆盖；已是新版时间线但缺失轨道时也会自动补齐。

API 字段、数据库结构、iOS 代码及本机 `.env` 均未改变。联调时应重启配置了开关的开发 API，
并重新启动包含新版资源的 Debug 客户端。生产环境禁用、两端 fixture 一致性、重复入库、
缺轨修复和开关恢复均由后端回归测试覆盖。

## 切片 8：耳畔轻语可复现导入

`scripts/import_fire_handoff.py <sc_ear_v01_review包路径>` 按包内 `scene_id` 选择耳语配置，
固定校验六个已审查输入文件及顶层 `audio_asset_index.csv` 的 SHA-256，再校验母带与应用 AAC 哈希。
交接包 `source_map.csv` 中鹅毛素材有一处已知的 62 位哈希笔误；导入器仅允许这一条精确值，
并继续用母带、总索引和应用素材目录三方校验真实内容，其他短哈希或不一致值都会失败。

生成的 `handoff_ear_v4.json` 在 App 与后端保持逐字节一致。600 秒时间线包含 244 个动作；
房间底噪循环使用 500 ms 交叉淡化，五条触发音按交接顺序单次播放。每条触发音首次播放前先把
envelope 设为 0，再执行 350 ms 渐入，避免从默认增益 1 向目标低增益衰减造成瞬时突响。
本切片不修改 API、数据库或环境配置，原始交接包保持不变。

## 切片 9：耳畔轻语远端联调

耳畔轻语使用独立稳定场景 ID，属于评审期间新增的目录项，不替换已有官方场景。
在 `development`、`local` 或 `test` 环境启用 `DW_ENABLE_HANDOFF_REVIEW_PRESETS=true` 后，
场景列表、详情和时间线会新增该场景及六条轨道；关闭开关后，目录项会取消发布，详情与时间线返回 404。
再次启用开关会恢复同一数据库记录，不重复创建场景或轨道。生产和预发布环境即使设置 true 也保持隐藏。

API 字段、数据库结构、iOS 代码及本机 `.env` 均未改变，不需要 Alembic 迁移。
联调客户端须使用包含 handoff 音频的新版 Debug 构建，并在切换开关后重启 API 与客户端。
fixture 一致性、首次新增、重复读取、缺轨修复、关闭隐藏、重新启用和生产环境禁用均由后端回归测试覆盖。

## 切片 10：翻页入眠可复现导入

`scripts/import_fire_handoff.py <sc_page_v01_review包路径>` 现在支持翻页场景，固定校验六个已审查输入文件
及顶层 `audio_asset_index.csv` 的 SHA-256，再校验十一条母带、应用 AAC 和逐素材审核状态。
生成的 App 与后端 `handoff_page_v4.json` 逐字节一致，不依赖 CI 中不存在的原始交接目录。

250 秒时间线保留三条循环层和 32 次串行触发，共生成 99 个 cue、355 个动作。导入器在把时间作为
cue 键之前统一保留六位小数，使 `238.26 + 10.92` 与交接文件中的 `249.18` 合并为同一个 cue，
避免相同 UUID 出现在两个时间点记录中。八条触发素材首次播放前都先把 envelope 置零，再执行
350 ms 渐入；三条循环素材分别保留 500 ms 交叉淡化。

来源包仍为 `release_ready=false`。十一条素材的 QC 和许可证、三条循环的接缝试听、触发音空间路径、
纸张与铅笔高频以及喝水/咀嚼素材的注意力影响仍是发布阻断项。本切片不修改 API、数据库、环境配置
或 App 运行时代码；远端目录接线留在下一切片。
