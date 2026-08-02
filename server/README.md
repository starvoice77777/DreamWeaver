# DreamWeaver Server

DreamWeaver 生产后端。集成分支已含阶段 5（授权 + SeedJob + 撤回级联）。阶段 6 起提供场景时间线契约。

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
- 就绪：http://127.0.0.1:8000/ready
- OpenAPI：http://127.0.0.1:8000/docs

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
| PUT | `/v1/users/me/scenes/{id}/draft` | Bearer | 更新草稿（不发布） |
| POST | `/v1/users/me/scenes/{id}/save` | Bearer | 显式保存正式版本 |
| DELETE | `/v1/users/me/scenes/{id}` | Bearer | 软删除个人场景 |
| POST | `/v1/uploads` | Bearer | 创建预签名上传会话（返回 `put_url`） |
| POST | `/v1/uploads/{id}/complete` | Bearer | 确认对象已上传并创建 `SoundAsset` |
| GET | `/v1/library/assets` | Bearer | 当前用户声音资产列表 |
| PATCH | `/v1/library/assets/{id}` | Bearer | 更新 name / symbol_name / is_favorite |
| POST | `/v1/library/assets/{id}/favorite` | Bearer | 切换收藏 |
| GET | `/v1/library/assets/{id}/delete-impact` | Bearer | 删除前受影响个人场景（二次确认 UI） |
| DELETE | `/v1/library/assets/{id}` | Bearer | 软删除；从个人场景草稿/正式版 scrub `assetId`；尽力删对象 |
| GET | `/v1/library/assets/{id}/playback-url` | Bearer | 短时私有播放 URL |
| POST | `/v1/voice-authorizations` | Bearer | 创建声音授权（`confirmed=true`） |
| GET | `/v1/voice-authorizations` | Bearer | 授权列表（含已撤回） |
| POST | `/v1/voice-authorizations/{id}/revoke` | Bearer | 撤回授权并级联：取消 SeedJob、软删种子资产、scrub 场景、尽力删供应商 stub |
| POST | `/v1/seeds/analyze` | Bearer | 质检（body: `duration_seconds`） |
| POST | `/v1/seeds/process` | Bearer | 启动 SeedJob（授权 + 已 complete 的源资产） |
| GET | `/v1/seeds/jobs/{id}` | Bearer | 轮询；stub 进度在此推进直至 `completed` |
| POST | `/v1/seeds/jobs/{id}/finalize` | Bearer | body: `name` + `relation` → `kind=voice` 资产 |
| DELETE | `/v1/seeds/jobs/{id}` | Bearer | 取消未完成任务 |

上传限制：扩展名 `m4a/mp3/wav/caf`；最大 25MB；`kind` ∈ `life|voice|environment|official`。客户端流程：`POST /uploads` → PUT 到 `put_url`（带 `required_headers`）→ `POST .../complete`。

Seed 流程：授权 → `analyze` → `process`（StubVoiceProvider）→ 轮询 `jobs/{id}` → `finalize`。进度对齐本地 iOS，**不依赖 Celery worker**；可选任务名 `seeds.advance_job` 仅骨架。

删除约定：先 `GET .../delete-impact` 展示受影响场景，再 `DELETE` 确认。声源 JSON 用 `assetId`（或 `asset_id`）关联资产。

首次访问内容接口时，若库中缺官方场景，会按需补齐与演示 UUID 对齐的完整目录（约 14 个场景，含「流光溢彩」`emotionalFluid`；多数可无完整音频资源，仅元数据与占位轨）。同时会为缺时间线的场景写入版本化 Cue/Phrase 文档；「洗头陪伴」对齐本地播放节奏（约 6s 首句、之后每 28s，并含音量/进度示例 cue）。

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

## Worker

```powershell
cd server
celery -A app.workers.celery_app:celery_app worker --loglevel=INFO
```

Windows 本地建议加 `--pool=solo`。

## 检查

```powershell
cd server
pytest
ruff check app tests
```

## 分支说明

- 集成分支：`integration/frontend-backend`（阶段 0–3 主路径已合入）
- 服务端鉴权：Apple JWKS + 开发 `dev:<sub>`
- iOS Remote（已合入）：
  - 游客：bootstrap / scenes / presets
  - 登录后：`RemoteAuthService` + `RemoteUserService`（home / 收藏 / 设置 / 显式保存）
  - 登录壳：`feat/ui-auth-shell`（Profile Sign in with Apple + 演示登录）

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

Seed 远程说明：在 Seed UI 尚未上传真实录音前，`startProcess` 会用包内 `voice_phrase_mom` 作为源资产走通 API。正式录音上传就绪后改为上传用户文件即可。

## 下一阶段

1. **阶段 0–5（已合入 integration）**：内容、上传、SeedJob、授权撤回级联、RemoteSeed、官方场景目录
2. **阶段 6 PR1（本分支）**：`GET /v1/scenes/{id}/timeline` 契约与官方种子时间线
3. 阶段 6 余量：iOS 调度器替换固定 28s 人声；私有场景保存携带 timeline 快照
4. 阶段 5 余量：真实供应商 PoC；前端「我的 → 授权与隐私」撤回 UI
5. 离线队列实现（契约见 `../docs/offline-queue-and-conflict.md`，本期仅文档）

完整方案见 `../docs/production-backend-architecture-and-roadmap.md`。
