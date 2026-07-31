# DreamWeaver Server

DreamWeaver 的生产后端基础工程。当前阶段提供 FastAPI、PostgreSQL、Redis、MinIO 和 Celery 的本地开发骨架，不包含真实声音供应商密钥。

## 本机直接运行 API

要求 Python 3.12 或更高版本。

```powershell
cd server
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -e ".[dev]"
Copy-Item .env.example .env
uvicorn app.main:app --reload
```

访问：

- 健康检查：http://127.0.0.1:8000/health
- OpenAPI：http://127.0.0.1:8000/docs
- API v1：http://127.0.0.1:8000/v1/

基础健康检查不要求 PostgreSQL、Redis 或 MinIO 已启动。业务接口接入后，`/ready` 将检查外部依赖。

## 使用 Docker Compose

先安装 Docker Desktop，然后：

```powershell
Copy-Item server\.env.example server\.env
docker compose -f infra\docker-compose.yml up --build
```

服务端口：

- API：8000
- PostgreSQL：5432
- Redis：6379
- MinIO API：9000
- MinIO Console：9001

开发环境中的账号和密码仅供本机使用，不得用于部署。

## Worker

在 Redis 可用时启动：

```powershell
cd server
celery -A app.workers.celery_app:celery_app worker --loglevel=INFO
```

当前包含 `system.ping` 测试任务和 `StubVoiceProvider`。真实声音供应商确定后通过同一 Provider 接口接入。

## 检查

```powershell
cd server
pytest
ruff check .
mypy app
```

## 下一阶段

1. Alembic 初始化和第一批用户、会话、场景数据库模型；
2. Sign in with Apple 服务端验证；
3. 场景列表、详情与 Bootstrap；
4. iOS `APIClient` 和 `RemoteContentService`；
5. 预签名上传和声音资产；
6. 授权、SeedJob 与第三方供应商 PoC。

完整方案见 `../docs/production-backend-architecture-and-roadmap.md`。

