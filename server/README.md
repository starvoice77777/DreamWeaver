# DreamWeaver Server

DreamWeaver 生产后端。阶段 **0–7** 已合入 `integration/frontend-backend`；本仓库本地收口含官方 catalog 强制对齐、`/ready` 依赖探活，以及阶段 8 部署准备材料（不上真实云）。

## 本机直接运行 API

要求 Python 3.12+。业务接口需要 PostgreSQL（可用 Docker Compose 只起依赖）。

```powershell
cd server
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -e ".[dev]"
Copy-Item .env.example .env

# 另开终端启动依赖
cd ..\infra
docker compose up -d postgres redis minio

cd ..\server
alembic upgrade head
uvicorn app.main:app --reload
```

访问：

- 健康检查：http://127.0.0.1:8000/health
- 就绪：http://127.0.0.1:8000/ready（探测 Postgres；默认再 PING Redis；MinIO/OSS **不**纳入就绪条件）
- 指标：http://127.0.0.1:8000/metrics（Prometheus 文本；进程内计数，重启清零）
- OpenAPI：http://127.0.0.1:8000/docs

每个响应带 `X-Request-ID`（可传入同名请求头以串联追踪）。访问日志为 JSON（stdout）；敏感操作写入 `audit_events`（登录 / 登出 / 删资产 / 撤回声音授权），并打 `dreamweaver.audit` 结构化日志。云告警与错误跟踪在阶段 8 接入；本地可对 `/metrics` 与 JSON 日志做抓取。

### 已提供的接口

| 方法 | 路径 | 鉴权 | 说明 |
|------|------|------|------|
| GET | `/v1/bootstrap` | 可选 Bearer | 问候语、默认场景、场景摘要、设置 |
| GET | `/v1/scenes` | 否 | 官方场景列表 |
| GET | `/v1/scenes/{id}` | 否 | 场景详情 + 音轨 |
| GET | `/v1/scenes/{id}/presets` | 否 | 场景混音预设 |
| GET | `/v1/scenes/{id}/timeline` | 否 | 版本化 Cue/Phrase 时间线（客户端调度） |
| GET | `/v1/presets` | 否 | 全部预设（可选 `scene_id`） |
| POST | `/v1/auth/apple` | 否 | Sign in with Apple：JWKS 验签；开发可用 `dev:<sub>` |
| POST | `/v1/auth/refresh` | 否 | 用 refresh_token 轮换会话 |
| POST | `/v1/auth/logout` | Bearer | 撤销当前 access 会话 |
| GET | `/v1/home` | Bearer | 推荐、最近、收藏、个人场景摘要 |
| GET/PUT | `/v1/users/me/settings` | Bearer | 用户设置 |
| PATCH | `/v1/users/me/scene-states/{id}` | Bearer | 收藏 / 标记最近使用 |
| POST | `/v1/scenes/{id}/copy` | Bearer | 从官方场景复制为个人草稿 |
| GET/POST | `/v1/users/me/scenes` | Bearer | 列出 / 空白创建个人场景 |
| GET | `/v1/users/me/scenes/{id}` | Bearer | 个人场景详情 |
| PUT | `/v1/users/me/scenes/{id}/draft` | Bearer | 更新草稿（可含 `draft_timeline` / `draft_composition`，不发布） |
| POST | `/v1/users/me/scenes/{id}/save` | Bearer | 显式保存正式版本（快照 sources / timeline / composition） |
| DELETE | `/v1/users/me/scenes/{id}` | Bearer | 软删除个人场景 |
| POST | `/v1/compositions/validate` | Bearer | 校验 `scene_composition_v1`（不落库；见 `docs/scene-composition-contract.md`） |
| POST | `/v1/uploads` | Bearer | 创建预签名上传会话（返回 `put_url`） |
| POST | `/v1/uploads/{id}/complete` | Bearer | 确认对象已上传并创建 `SoundAsset` |
| GET | `/v1/library/assets` | Bearer | 当前用户声音资产列表 |
| PATCH | `/v1/library/assets/{id}` | Bearer | 更新 name / symbol_name / is_favorite |
| POST | `/v1/library/assets/{id}/favorite` | Bearer | 切换收藏 |
| GET | `/v1/library/assets/{id}/delete-impact` | Bearer | 删除前受影响个人场景（二次确认 UI） |
| DELETE | `/v1/library/assets/{id}` | Bearer | 软删除；从个人场景草稿/正式版 scrub `assetId`；尽力删对象 |
| GET | `/v1/library/assets/{id}/playback-url` | Bearer | 短时私有播放 URL |
| POST | `/v1/voice-authorizations` | Bearer | **[deprecated]** 创建声音授权（`confirmed=true`） |
| GET | `/v1/voice-authorizations` | Bearer | **[deprecated]** 授权列表（含已撤回） |
| POST | `/v1/voice-authorizations/{id}/revoke` | Bearer | **[deprecated]** 撤回授权并级联：取消 SeedJob、软删种子资产、scrub 场景、尽力删供应商 stub |
| POST | `/v1/seeds/analyze` | Bearer | **[deprecated]** 质检（body: `duration_seconds`） |
| POST | `/v1/seeds/process` | Bearer | **[deprecated]** 启动 SeedJob（授权 + 已 complete 的源资产） |
| GET | `/v1/seeds/jobs/{id}` | Bearer | **[deprecated]** 轮询；stub 进度在此推进直至 `completed` |
| POST | `/v1/seeds/jobs/{id}/finalize` | Bearer | **[deprecated]** body: `name` + `relation` → `kind=voice` 资产 |
| DELETE | `/v1/seeds/jobs/{id}` | Bearer | **[deprecated]** 取消未完成任务 |
| POST | `/v1/analytics/events` | Bearer | 批量上报陪伴事件（对齐 iOS `AnalyticsEvent`） |
| GET | `/v1/analytics/summary` | Bearer | 陪伴摘要（对齐 iOS `UsageRecord`） |
| POST | `/v1/admin/reseed-catalog` | 否 | **非 production**：upsert 官方场景元数据 / 音轨 / 预设并刷新时间线（不删孤儿轨） |

上传限制：扩展名 `m4a/mp3/wav/caf`；最大 25MB；`kind` ∈ `life|voice|environment|official`。客户端流程：`POST /uploads` → PUT 到 `put_url`（带 `required_headers`）→ `POST .../complete`。

Seed 流程：授权 → `analyze` → `process`（StubVoiceProvider）→ 轮询 `jobs/{id}` → `finalize`。进度对齐本地 iOS，**不依赖 Celery worker**；可选任务名 `seeds.advance_job` 仅骨架，正式异步执行留阶段 8 之后。

**产品废弃（PRD v1.3）**：语音克隆 / Seed 产品路径已取消；上述 Seed 与 VoiceAuthorization 接口保留但标记 **deprecated**，仅供开发遗留与回归测试。用户「创建」请使用 `scene_composition_v1`（契约 `docs/scene-composition-contract.md`；前端隐藏 Seed 入口见 `docs/frontend-handoff-scene-composition.md`）。

删除约定：先 `GET .../delete-impact` 展示受影响场景，再 `DELETE` 确认。声源 JSON 用 `assetId`（或 `asset_id`）关联资产。

首次访问内容接口时，若库中缺官方场景，会按需补齐与演示 UUID 对齐的完整目录（约 13 个场景，含雨檐 `rainEaves` 与竹叶轨；多数可无完整音频资源，仅元数据与占位轨）。已下架场景会保留历史数据但不再出现在公开目录中。同时会为缺时间线的场景写入版本化 Cue/Phrase 文档；「洗头陪伴」使用脚本 **v4**，「檐下听雨」使用 **v2**。

### 官方 catalog 强制对齐（无需清库）

`ensure_official_catalog` 对**已存在**场景默认跳过整场插入。旧库若缺竹叶轨或 `resource_key` 过期，任选其一：

1. **HTTP（推荐开发机）**：`POST /v1/admin/reseed-catalog`（`DW_ENVIRONMENT=production` 时返回 403）
2. **启动开关**：`.env` 设 `DW_FORCE_RESEED_CATALOG=true` 后重启 API（生产环境忽略）

行为：按 track / preset **id upsert**；**不删除**规格中已去掉的轨（避免破坏私人快照引用）。

### Sign in with Apple

生产路径会向 `DW_APPLE_JWKS_URL`（默认 Apple 公钥）拉取 JWKS，用 RS256 校验 `identity_token`，并核对：

- `iss` = `DW_APPLE_ISSUER`（默认 `https://appleid.apple.com`）
- `aud` = `DW_APPLE_CLIENT_ID`（默认 Bundle ID `zhimeng.DreamWeaver`）
- `exp` / `iat` / `sub`
- 可选 `nonce`：请求体可带原始 nonce；服务端接受与 claim 相等，或与 `SHA-256(nonce)` 的 hex 相等

本地开发默认允许 `identity_token` 形如 `dev:<apple_sub>`（`DW_ENVIRONMENT=development|test|local`，或显式 `DW_ALLOW_DEV_APPLE_AUTH=true`）。生产请设 `DW_ALLOW_DEV_APPLE_AUTH=false`。

开发登录示例（PowerShell）：

```powershell
'{"identity_token":"dev:demo-user","nickname":"夜行者"}' | Set-Content $env:TEMP\dw-auth.json -Encoding ascii
curl.exe -s -X POST http://127.0.0.1:8000/v1/auth/apple -H "Content-Type: application/json" --data-binary "@$env:TEMP\dw-auth.json"
```

## 使用 Docker Compose

```powershell
Copy-Item server\.env.example server\.env
docker compose -f infra\docker-compose.yml up --build
```

端口：API 8000 / Postgres 5432 / Redis 6379 / MinIO 9000·9001。

生产形态样例（无真实密钥）：见 `../infra/docker-compose.prod.example.yml` 与 `../docs/deploy-china-checklist.md`。

## Worker

Compose 已包含 `worker` 服务。Seed **主路径不依赖** Worker（API 轮询推进 stub 进度）。Worker 用于验证 Celery ↔ Redis 连通与后续异步任务骨架。

本机单独启动：

```powershell
cd server
.\.venv\Scripts\Activate.ps1
celery -A app.workers.celery_app:celery_app worker --loglevel=INFO --pool=solo
```

另开终端验证 ping（需 Redis 已起）：

```powershell
cd server
.\.venv\Scripts\Activate.ps1
celery -A app.workers.celery_app:celery_app call system.ping
```

预期输出含 `{"status": "ok"}`。任务 `seeds.advance_job` 当前为 noop 骨架。

Compose 一键（含 worker）：

```powershell
docker compose -f infra\docker-compose.yml up --build api worker postgres redis minio
```

## 检查

```powershell
cd server
pytest
ruff check app tests
```

## 分支说明

- 集成分支：`integration/frontend-backend`（阶段 0–7 + 本地收口）
- 服务端鉴权：Apple JWKS + 开发 `dev:<sub>`
- iOS Remote（已合入）：
  - 游客：bootstrap / scenes / presets / timeline
  - 登录后：`RemoteAuthService` + `RemoteUserService`（home / 收藏 / 设置 / 显式保存）
  - Analytics：`RemoteAnalyticsService`

冒烟（API 已启动时）：

```powershell
.\scripts\smoke_remote_auth.ps1
```

### iOS 登录后调用约定（给前端）

| AppState API | 用途 |
|--------------|------|
| `signInWithApple(identityToken:nonce:)` | Apple 登录完成后写入 Keychain 并拉 home |
| `signInWithDevAccount(sub:)` | 本地烟雾（仅开发） |
| `signOutRemote()` | 退出并清 Token |
| `isRemoteAuthenticated` / `sessionUserId` | 会话态 |
| `toggleFavorite` / `persistSettings` | 已登录时自动走远程 API |
| `saveCurrentMix()` / `saveCurrentMixToRemote()` | **显式**保存个人场景（勿在拖拽时自动调） |
| `toggleSoundFavorite` / `renameSound` / `deleteSound` | 远程模式下走 `/v1/library/assets` |
| `fetchSoundDeleteImpact(id:)` | 删除前二次确认（受影响场景） |
| `remoteLibraryService?.uploadAudio(...)` | 预签名上传新建资产（Seed / 导入） |
| `seedPipeline`（远程模式） | `RemoteSeedPipelineService`：授权 / analyze / process / poll / finalize；未登录回退本地 |

Seed 远程说明：Seed UI 选择本地音频后，`startProcess` 会上传该文件作为源资产；未选择文件时回退到包内 `voice_phrase_mom`，用于走通 API。

## 下一阶段

1. **阶段 0–7（已完成）**：内容、上传、Seed、时间线、Analytics、可观测性
2. **本地收口（本轮）**：雨檐 catalog、`POST /v1/admin/reseed-catalog`、`/ready` 探活、部署清单
3. **阶段 8**：中国大陆云部署（见 `../docs/deploy-china-checklist.md`）——需企业主体 / 域名备案 / 云账号后执行
4. 阶段 5 余量：真实供应商 PoC；前端「我的 → 授权与隐私」撤回 UI
5. 离线队列实现（契约见 `../docs/offline-queue-and-conflict.md`，本期仅文档）

完整方案见 `../docs/production-backend-architecture-and-roadmap.md`。
