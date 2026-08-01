# DreamWeaver Server

DreamWeaver 生产后端。当前在 `feat/presigned-upload`：阶段 4 PR1（预签名上传 + 用户声音库只读列表 / 播放 URL）。

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
| GET | `/v1/library/assets/{id}/playback-url` | Bearer | 短时私有播放 URL |

上传限制：扩展名 `m4a/mp3/wav/caf`；最大 25MB；`kind` ∈ `life|voice|environment|official`。客户端流程：`POST /uploads` → PUT 到 `put_url`（带 `required_headers`）→ `POST .../complete`。

首次访问内容接口时，若库中无场景，会自动写入与演示 UUID 对齐的官方种子（洗头陪伴、檐下听雨等）。

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

## 下一阶段

1. **阶段 4 PR1（进行中）**：预签名上传 + list/playback-url（本分支）
2. **阶段 4 PR2**：资产 PATCH / 收藏 / 删除影响面
3. **阶段 4 PR3**：iOS `RemoteUserLibraryService`
4. 阶段 5：SeedJob / StubVoiceProvider
5. 离线队列实现（契约见 `../docs/offline-queue-and-conflict.md`，本期仅文档）

完整方案见 `../docs/production-backend-architecture-and-roadmap.md`。
