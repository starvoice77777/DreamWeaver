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

1. 绑定/素材门禁与预设解析：仅审核通过的候选，保护锁定和排除，缺依赖明确失败。
2. SceneDraft 及结果契约：决策、版本和失败/澄清状态可追溯。
3. 首个确定性编译器与时间线验证：固定雨声测试资源通过 Schema 和语义检查。
4. 受约束 AI 排序与提示词：只返回候选 ID/预设决策；禁止生成 cues、坐标或时间。
   非法模型输出和模型不可用时使用规则回退；用户文本作为不可信数据隔离。
5. 新 API、幂等和缓存：按依赖版本隔离缓存，鉴权、版本冲突及前端契约联调。
6. 单轨调整与后台 C 级任务：锁定轨和无关轨保持不变，保存变化递增版本。

每个切片单独测试、提交、审查；超过约 300 行再次拆分。切换前端前先部署新服务。
不能直接用新提示词替换旧的 outline/arrangement/compile 提示词：输出契约不同。

## 待产品/素材与前端确认

- 包内绑定 CSV 仅有表头，素材需求为 planned/pending/draft；fixture 不能升级为生产资源。
- 缺少可执行且审核通过的脚本、预设、运动与绑定注册表，以及耳部禁行区参数。
- 文档要求拒绝未知状态，但 Schema 未枚举状态；评分文档与 CSV 的状态命名有差异。
- 失败结果 Schema 仍强制已解析的预设/脚本：无法解析时的返回表示需确认，不编造 ID。
- 后续前端需传入目标/状态/框架/锁定/来源版本，并处理澄清、回退和系统补充确认。
