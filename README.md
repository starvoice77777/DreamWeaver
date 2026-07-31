# DreamWeaver

助眠场景编排 iOS 应用。仓库同时保留复赛离线演示实现，并开始建设生产服务器。

## 团队协作

- 前后端 Git 协作说明（给双方）：[docs/frontend-backend-collaboration.md](docs/frontend-backend-collaboration.md)

## 生产后端

- 技术方案：[docs/production-backend-architecture-and-roadmap.md](docs/production-backend-architecture-and-roadmap.md)
- 后端工程：[server/README.md](server/README.md)
- 本地服务编排：[infra/docker-compose.yml](infra/docker-compose.yml)

生产后端当前处于**阶段 2**：数据库模型、Bootstrap / 场景 API、开发用 Apple 登录已可用；iOS 仍默认 Local Mock，不影响前端并行改 UI。

## 复赛阶段说明

- 不部署远程后端；使用 Bundle 假数据 + 本地 `AVAudioEngine` 多轨播放。
- 主演示场景：**洗头陪伴**；备用：**檐下听雨**。
- 契约与验证清单见：
  - [docs/demo-backend-contract.md](docs/demo-backend-contract.md)
  - [docs/audio-licenses.md](docs/audio-licenses.md)
  - [docs/verification-checklist.md](docs/verification-checklist.md)

## 架构（可替换）

SwiftUI Views → `AppState` → Service Protocols → Local Mock 实现
赛后可将 Local 实现替换为 Remote API，无需重写页面。

| 协议 | 本地实现 |
|------|----------|
| ContentService | LocalContentService |
| UserLibraryService | LocalUserLibraryService |
| SeedPipelineService | LocalSeedPipelineService |
| AnalyticsService | LocalAnalyticsService |
| PlaybackService | LocalPlaybackService |

## 拍摄前

设置 → 演示控制 → **重置为标准演示状态**。

## 音频

素材在 `DreamWeaver/Resources/Audio/`。人声短句 `voice_phrase_mom` 当前为静音占位，请按 `scripts/prepare_demo_audio.md` 替换并转码。
