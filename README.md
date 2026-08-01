# DreamWeaver

助眠场景编排 iOS 应用。仓库同时保留复赛离线演示实现，并开始建设生产服务器。

## 团队协作

- 前后端 Git 协作说明（给双方）：[docs/frontend-backend-collaboration.md](docs/frontend-backend-collaboration.md)

## 生产后端

- 技术方案：[docs/production-backend-architecture-and-roadmap.md](docs/production-backend-architecture-and-roadmap.md)
- 后端工程：[server/README.md](server/README.md)
- 本地服务编排：[infra/docker-compose.yml](infra/docker-compose.yml)

生产后端当前处于**阶段 2/3 API + Apple JWKS**；iOS 在 `feat/ios-remote-content` 可切换 Remote 游客读内容，默认仍为 Local Mock。

## 复赛阶段说明

- 不部署远程后端；使用 Bundle 假数据 + 本地 `AVAudioEngine` 多轨播放。
- 主演示场景：**洗头陪伴**；备用：**檐下听雨**。
- 契约与验证清单见：
  - [docs/demo-backend-contract.md](docs/demo-backend-contract.md)
  - [docs/audio-licenses.md](docs/audio-licenses.md)
  - [docs/verification-checklist.md](docs/verification-checklist.md)

## 架构（可替换）

SwiftUI Views → `AppState` → Service Protocols → Local / Remote 实现

| 协议 | 本地实现 | 远程实现（`feat/ios-remote-content`） |
|------|----------|--------------------------------------|
| ContentService | LocalContentService | RemoteContentService（游客可读） |
| UserLibraryService | LocalUserLibraryService | （阶段 4） |
| SeedPipelineService | LocalSeedPipelineService | （阶段 5） |
| AnalyticsService | LocalAnalyticsService | （阶段 7） |
| PlaybackService | LocalPlaybackService | 本轮仍本地多轨 |

### iOS ↔ 本机 API 联调

1. 启动依赖与 API：见 [server/README.md](server/README.md)（`http://127.0.0.1:8000`）
2. 设置 → 演示控制 → **内容数据源** 选「远程 API」→ **完全退出 App 再打开**
3. 游客可读：`/v1/bootstrap`、`/v1/scenes`、详情、`/v1/presets`
4. Token 存 Keychain；`RemoteAuthService` 已预留 Apple / `dev:<sub>` 登录（UI 登录壳由前端 `feat/ui-auth-shell`）
5. 真机请把基址改为电脑局域网 IP：`UserDefaults` 键 `dw.apiBaseURL`（例如 `http://192.168.1.8:8000`）

当前默认仍是**本地演示**，不影响前端并行改 UI。

## 拍摄前

设置 → 演示控制 → **重置为标准演示状态**。

## 音频

素材在 `DreamWeaver/Resources/Audio/`。人声短句 `voice_phrase_mom` 当前为静音占位，请按 `scripts/prepare_demo_audio.md` 替换并转码。
