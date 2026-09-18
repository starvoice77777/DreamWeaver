# AI 辅助创建迁移：2026-09-18

## 切片 1：请求契约与门禁

新增内部入口 `app.schemas.ai_generation.validate_generation_request(payload)`，
按产品 `ai-scene-generation-v1` 请求 Schema 校验，并检查重复 `sound_object_id`。
原样保留省略字段、用户锁定、排除列表、种子与手动覆盖记录；不推测默认目标。
五类框架只能使用各自的状态；用户选择声音数量为 1–4；调整必须提供来源版本。
Schema 接受非空状态标签；标签字典与框架区域适配留给后续版本化注册表验证。

Schema 与请求样例来自 `backend_ai_scene_debug_handoff_2026-09-18`，
只规范化文件末尾空行，JSON 内容与源文件一致。源文件校验值：
- Schema SHA256：`abd33db624a59e1b6afe7fc6720a2894595f03a1443ca556fffb41a16198d5b0`
- 样例 SHA256：`1f5b67a492ddd79953906d98b5a10a039cdd34458a8d4ae0348a42bc2da6e269`

校验失败抛出 `GenerationRequestError`，提供 `code` 和字段 `path`，错误文本不回显输入。
数量超限、未知目标、未知框架有专用代码，其他结构错误使用 `INVALID_REQUEST`。
拒绝 NaN/Infinity；门禁不代表素材获批，也不代表调整来源版本与数据库一致。

运行依赖增加 `jsonschema>=4.18,<5`；无数据库、环境变量或旧 API 变更。
安装项目依赖后，在 `server` 运行 `python -m pytest tests/test_ai_generation_request.py`。
现有 `/v1/ai/scene-assist/*` 和 iOS 调用保持原契约；新门禁尚未接入公开路由。

本切片验证：完整 pytest 126 项通过（新门禁 29 项），`ruff check app tests` 通过，
wheel 包包含 Schema。`ruff check .` 的 36 项失败位于未改动的 Alembic 文件。
未验证真实模型调用、运行中的基础设施与 iOS 播放；本切片不具备完整生成能力。

## 后续独立切片与验收

1. 内容预设解析与完整候选过滤：从已获批绑定继续检查预设、角色和运动兼容性。
2. SceneDraft 及结果契约：决策、版本和失败/澄清状态可追溯。
3. 首个确定性编译器与时间线验证：固定雨声测试资源通过 Schema 和语义检查。
4. 受约束 AI 排序与提示词：只返回候选 ID/预设决策；禁止生成 cues、坐标或时间。
   非法模型输出和模型不可用时使用规则回退；用户文本作为不可信数据隔离。
5. 新 API、幂等和缓存：按依赖版本隔离缓存，鉴权、版本冲突及前端契约联调。
6. 单轨调整与后台 C 级任务：锁定轨和无关轨保持不变，保存变化递增版本。

每个切片单独测试、提交、审查；超过约 300 行再次拆分。切换前端前先部署新服务。
不能直接用新提示词替换旧的 outline/arrangement/compile 提示词：输出契约不同。

## 切片 2A：用户所选素材与绑定门禁

内部入口 `app.services.ai_generation_bindings.resolve_selected_bindings` 先执行请求门禁，
再读取调用方提供的固定版本 `AssetCatalog` 与 `FrameBindingIndex`。
这些类型只是服务端记录的最小投影，不是公开 API、完整注册表或生产种子。
目录适配器须提供真实审核依据：`asset_status=master`、`license_status=approved`、
内部投影 `qc_status=approved`；缺失或未知状态不可推定通过。
每个所选资源在目录中必须唯一，在当前框架中必须有唯一且 `approved` 的绑定，
绑定 ID、版本、区域及两个依赖版本必须非空白。显式 `desired_zone` 必须与绑定相符。
返回独立请求副本、按用户选择顺序排列的绑定及依赖版本，保留锁定与排除等字段。
选中且排除同一资源、缺失/重复记录、未获批素材或绑定均失败，不替换或删除用户声音。
`BindingGateError` 提供 `NO_APPROVED_BINDING`、细分 `reason_code` 和字段路径，
不在错误消息中回显资源键或自由文本；上层后续据此生成澄清/适配结果。
运行 `python -m pytest tests/test_ai_generation_bindings.py` 验证门禁。
开发依赖补充 `types-jsonschema`，支持请求门禁和绑定模块的严格 mypy 检查。
命令为 `python -m mypy --follow-imports=silent app/schemas/ai_generation.py
app/services/ai_generation_bindings.py`（一行执行），保留两个目标模块的严格检查。
默认跟随导入时，未修改的旧模块仍有 57 项错误；本轮不声称全仓 mypy 通过。
本轮尚未接入数据库/鉴权、生产审核注册表、预设/角色/运动校验、系统补充或模型，
通过门禁不代表可播放；测试中的 `fixture_*` 审核状态仅为合成数据。
PR #10 的非空白标识符、长度及列表/请求体规模建议仍需在公开接线前统一契约并测试。

## 待产品/素材与前端确认

- 包内绑定 CSV 仅有表头，素材需求为 planned/pending/draft；fixture 不能升级为生产资源。
- 缺少可执行且审核通过的脚本、预设、运动与绑定注册表，以及耳部禁行区参数。
- 文档要求拒绝未知状态，但 Schema 未枚举状态；评分文档与 CSV 的状态命名有差异。
- 失败结果 Schema 仍强制已解析的预设/脚本：无法解析时的返回表示需确认，不编造 ID。
- 后续前端需传入目标/状态/框架/锁定/来源版本，并处理澄清、回退和系统补充确认。
