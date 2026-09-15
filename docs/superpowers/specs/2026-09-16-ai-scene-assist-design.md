# AI Scene Assist 设计规格

## 目标

为 DreamWeaver 创建页增加一个后端 AI 辅助编排能力：用户提交已选声源的描述信息后，服务通过 DeepSeek `deepseek-v4-pro` 依次生成场景基调、大纲和详细编排，最后输出可直接导入现有创建页的 `scene_composition_v2` 场景；已有场景也可以通过自然语言请求调整并返回完整的新场景。

## 边界与兼容性

- 只修改 `server/**` 和本目录下的后端设计/交接文档，不修改 `DreamWeaver/Models/**`、`AppState.swift` 或 View。
- 最终 `composition` 必须经过现有 `validate_composition` 归一化，沿用 `source_groups`、`clips`、位置关键帧、时间窗、循环和淡化字段。
- 模型只能引用请求中的 `source_id` 或 `resource_key`，服务端拒绝未选资源、非法范围和不符合契约的 UUID。
- AI 结果是草稿，不代表素材 QC、许可证或人工试听已经通过；响应会明确验证警告。

## API

所有端点位于 `/v1/ai/scene-assist`，使用现有 Bearer 鉴权。

### 输入

`selected_sources[]` 至少包含 `source_id`、`resource_key`、`name`、`description`、`layer`、`loop`、`duration_seconds`、`default_volume`、`angle`、`radius`；可选 `scene_intent`、`duration_seconds`、`language`、`constraints`。

### 阶段端点

- `POST /outline`：返回 `outline`，包括 `name`、`subtitle`、`description`、`theme`、`use_case_tags`、`composition_profile`、`foreground_priority`、`trigger_focus`、`duration_policy`、`spatial_policy`、`trigger_mode` 和按时间段排列的 `sections`。
- `POST /arrangement`：输入 `outline` 与素材，返回每个来源的 `role`、`start_seconds`、`end_seconds`、`loop`、`default_volume`、`fade_in_ms`、`fade_out_ms` 和空间关键帧。
- `POST /compile`：输入 `outline`、`arrangement` 与素材，返回完整 `scene` 包和归一化 `composition`。
- `POST /generate`：顺序执行上述三个阶段，返回三个中间结果和最终场景包。
- `POST /adjust`：输入现有场景包与自然语言 `instruction`，返回完整调整后场景、`change_summary` 和校验警告。

## 模型调用

- 默认地址 `https://api.deepseek.com/chat/completions`，默认模型 `deepseek-v4-pro`；均可由设置覆盖。
- 使用 `response_format={"type":"json_object"}`，系统提示明确要求只输出 JSON，并提供最小字段示例。
- 每次响应先解析 JSON，再由 Pydantic 校验阶段结构；最终组合调用现有组合校验器。
- 解析或校验失败时将错误摘要追加到修复提示并重试一次；仍失败返回 502。缺少 API key 返回 503。
- 不记录 API key、完整提示词或可能包含用户内容的原始响应；日志只保留阶段、模型、耗时和 token 用量摘要。

## 配置

在 `server/app/core/config.py` 增加：

- `DW_DEEPSEEK_API_KEY`：必填密钥，占位值为空。
- `DW_DEEPSEEK_BASE_URL`：默认 `https://api.deepseek.com`。
- `DW_DEEPSEEK_MODEL`：默认 `deepseek-v4-pro`。
- `DW_DEEPSEEK_TIMEOUT_SECONDS`：默认 90。
- `DW_DEEPSEEK_MAX_RETRIES`：默认 1。

真实密钥只填写 `server/.env`（该文件不提交）；开发者可复制 `server/.env.example`。生产环境使用部署平台 Secret 注入同名 `DW_` 变量。

## 提示词规则

提示词将现有 `scene-composition-spec-v1.2`、`scene-creation-spec-v1.1` 和 `scene-timeline-contract` 的关键规则固化为约束：bed/ambience/action/trigger/voice 角色分离；角度使用弧度；半径和包络在 0…1；时间单调；连续触发目标间隔 2–6 秒、暂定上限 8 秒；同一触发实例内移动，不复制两份制造穿耳；不得添加音乐、未选择资源或医疗承诺；结尾使用平滑淡出。

## 测试与验证

- 单元测试覆盖设置、提示词 JSON 示例、DeepSeek 响应解析、重试、资源引用拒绝、组合归一化和调整结果。
- API 测试使用 mock HTTP，不访问真实 DeepSeek；覆盖 503/502、鉴权、阶段响应和 `/generate` 串联。
- 使用 `server/.venv/Scripts/python.exe -m pytest`、Ruff、`git diff --check`；真实 API 调用和人工听感属于未验证项。
