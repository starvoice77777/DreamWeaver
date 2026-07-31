# DreamWeaver Server

DreamWeaver 生产后端。当前完成阶段 2 前半：Alembic 模型、官方场景目录、Bootstrap / 场景 API，以及开发用 Apple 登录占位。

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

### 阶段 2 已提供的接口

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/v1/bootstrap` | 问候语、默认场景、场景摘要、默认设置 |
| GET | `/v1/scenes` | 官方场景列表 |
| GET | `/v1/scenes/{id}` | 场景详情 + 音轨 |
| GET | `/v1/scenes/{id}/presets` | 场景混音预设 |
| GET | `/v1/presets` | 全部预设（可选 `scene_id`） |
| POST | `/v1/auth/apple` | 开发登录：`identity_token` 可用 `dev:<sub>` |

首次访问内容接口时，若库中无场景，会自动写入与演示 UUID 对齐的官方种子（洗头陪伴、檐下听雨等）。

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

## 检查

```powershell
cd server
pytest
ruff check app tests
```

## 分支说明

本阶段后端工作在 `feat/server-models`，与前端 `feat/ui-frontend-sync` 并行；合入前以 `integration/frontend-backend` 为底。

## 下一阶段

1. Apple JWKS 正式验签（替换 `dev:` 占位）
2. 鉴权中间件保护用户态接口
3. 首页 / 收藏 / 个人场景显式保存
4. iOS `APIClient` + `RemoteContentService`（与前端约定后再动 AppState）
5. 预签名上传与 SeedJob

完整方案见 `../docs/production-backend-architecture-and-roadmap.md`。
