# DreamWeaver Server

DreamWeaver 生产后端。当前在 `feat/api-home-user`：阶段 2 内容 API + 阶段 3 鉴权依赖、首页、收藏与个人场景显式保存。

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
| POST | `/v1/auth/apple` | 否 | 开发登录：`identity_token` 可用 `dev:<sub>` |
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

首次访问内容接口时，若库中无场景，会自动写入与演示 UUID 对齐的官方种子（洗头陪伴、檐下听雨等）。

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

- 阶段 2 底：`feat/server-models`
- 本阶段：`feat/api-home-user`（仅 `server/`，不动 iOS）
- 与前端 `feat/ui-frontend-sync` 并行；合入前以 `integration/frontend-backend` 为底

## 下一阶段

1. Apple JWKS 正式验签（替换 `dev:` 占位）
2. iOS `APIClient` + `RemoteContentService`（与前端约定后再动 AppState）
3. 预签名上传与 SeedJob
4. 离线队列 / 冲突策略细化

完整方案见 `../docs/production-backend-architecture-and-roadmap.md`。
