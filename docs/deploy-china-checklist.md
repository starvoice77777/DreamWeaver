# 中国大陆部署清单（阶段 8 准备）

> 状态：**准备材料**，未宣称已上云。  
> 日期：2026-08-02  
> 本地后端收口完成后，具备企业主体与云账号再逐项执行。

## 1. 主体与合规

- [ ] 企业营业执照 / 云账号实名主体
- [ ] ICP 备案（域名）与公安备案（如适用）
- [ ] 隐私政策与用户协议上线 URL
- [ ] 个人信息保护影响评估（PIPL）要点评审
- [ ] Sign in with Apple / 国内登录备选方案确认（若商店分发要求）

## 2. 域名与证书

- [ ] 注册 API 域名（如 `api.example.com`）
- [ ] HTTPS 证书（云厂商证书或 Let's Encrypt）
- [ ] DNS 解析指向负载均衡 / 网关

## 3. 数据与中间件

- [ ] RDS PostgreSQL（多 AZ 或至少自动备份）
- [ ] Tair / Redis（会话、限流、Celery broker）
- [ ] 对象存储 OSS + 私有桶 + 预签名上传
- [ ] CDN（公开静态资源；私有音频仍走短时签名 URL）
- [ ] 密钥托管（KMS / 环境变量注入，禁止提交 `.env`）

## 4. 计算与发布

- [ ] ECS / SAE / ACK 任选其一托管 API
- [ ] Worker 独立进程/实例（Celery）；Seed 主路径仍可不依赖 Worker，直至异步供应商落地
- [ ] 镜像构建（见 `server/Dockerfile`）与滚动发布
- [ ] 参考形态：`infra/docker-compose.prod.example.yml`（样例，无真实 endpoint）
- [ ] 迁移：`alembic upgrade head` 纳入发布流水线

## 5. 可观测与运维

- [ ] 抓取 `/metrics` 或接入云监控
- [ ] 集中日志（JSON stdout → SLS / CLS）
- [ ] 告警：5xx、`/ready` 失败、磁盘与连接池
- [ ] 错误跟踪（Sentry 或云厂商 APM）
- [ ] 备份恢复演练（RDS + 对象存储生命周期）

## 6. 应用配置对照

| 本地 (`DW_*`) | 生产建议 |
|---------------|----------|
| `DW_ENVIRONMENT=development` | `production` |
| `DW_ALLOW_DEV_APPLE_AUTH` 默认开 | **必须** `false` |
| `DW_FORCE_RESEED_CATALOG` | **勿开**；catalog 变更走迁移/受控作业 |
| `DW_DATABASE_URL` | RDS 连接串（SSL） |
| `DW_REDIS_URL` | Tair 内网地址 |
| `DW_OBJECT_STORAGE_*` | OSS endpoint / AKSK / 私有桶 |
| `/ready` | 纳入负载均衡健康检查（Postgres + Redis） |

## 7. 明确不在本清单自动完成的事项

- 购买云资源与填写真实密钥
- 真实 TTS / 声音克隆供应商 PoC 合同与联调
- 客户端离线队列实现（见 `offline-queue-and-conflict.md`）
