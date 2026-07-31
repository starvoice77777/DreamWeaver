# DreamWeaver 复赛演示后端契约

版本：`demo-contract-v1`  
Schema：`1`  
日期：2026-07-30  
范围：离线 Bundle JSON + 本地 AVAudioEngine，不部署远程服务。

## 1. 演示主流程（视频逐镜）

| 镜号 | 画面 | 固定输入 | 预期输出 |
|------|------|----------|----------|
| 1 | 冷启动问候 | App 首次/重置后启动 | 问候语来自固定池；进入「洗头陪伴」 |
| 2 | 此刻沉浸 | 自动播放开启 | 多轨环境音循环；控件 5s 后淡出 |
| 3 | 场景详情 | 上拉/长按 | 显示定时、收听人数（演示值）、混音板 |
| 4 | 空间调音 | 拖动雨声/水流至左侧近处 | 音量变大、左声道增强 |
| 5 | 添加人声 | 将「妈妈的晚安」拖入圆内 | 人声短句按节奏触发（预录制） |
| 6 | 声音种子 | 走完录制→质检→授权→处理 | 固定「质量良好」+ 进度文案 + 生成种子资产 |
| 7 | 定时渐隐 | 选择「演示加速 45s」 | 短句停 → 人声淡出 → 环境声淡出 → 暂停 |
| 8 | 陪伴记录 | 打开「我的」 | 累计/本周时长与趋势已更新 |
| 9 | 备用场景 | 「全部」→「檐下听雨」→进入 | 雨+风多轨可播，混音可调 |

拍摄前：设置 →「演示控制」→「重置为标准演示状态」。

## 2. 固定场景 ID

| 角色 | 名称 | UUID |
|------|------|------|
| 主演示 | 洗头陪伴 | `a1111111-1111-4111-8111-111111111101` |
| 备用 | 檐下听雨 | `a1111111-1111-4111-8111-111111111102` |
| 默认种子 | 妈妈的晚安 | `b2222222-2222-4222-8222-222222222201` |
| 演示人声短句轨 | voice_phrase_mom | 资源名 `voice_phrase_mom.m4a`（团队提供后替换占位） |

其他目录场景仍有固定 UUID，用于展示与浏览，但 `isDemoPlayable=false`，无完整多轨清单时回退为静音 + UI 状态。

## 3. Service 协议（赛后可远程替换）

### ContentService
- `loadBootstrap() -> BootstrapPayload`
- `fetchScenes() -> [DreamScene]`
- `fetchScene(id:) -> DreamScene`
- `fetchMixPresets(sceneStyle:) -> [MixPreset]`
- `randomGreeting() -> String`

### UserLibraryService
- `fetchAssets(segment:) -> [SoundAsset]`
- `upsert(_ asset:)` / `delete(id:)` / `toggleFavorite(id:)`

### SeedPipelineService
- `analyze(sample:) -> SeedQualityReport`（演示固定通过）
- `authorize(confirmed:) throws`
- `startProcess(input:) -> SeedJob`
- `pollJob(id:) -> SeedJob`（进度 0→1，消息三阶段）
- `finalize(jobId:name:relation:) -> SoundAsset`

### AnalyticsService
- `summary() -> UsageRecord`
- `record(event: AnalyticsEvent)`
- `resetDemoStats()`

### PlaybackService
- `load(scene:sources:)`
- `play()` / `pause()` / `stop()`
- `updateSource(id:volume:pan:enabled:)`
- `preview(assetId:resourceName:)`
- `startSleepTimer(option:accelerated:)`
- `performLayeredFade(phases:)`

## 4. 预设输入 → 输出

### 声音种子成功路径
输入：任意模拟录音时长 ≥ 3s，勾选授权。  
输出：
```json
{
  "clarity": "良好",
  "noiseLevel": "较低",
  "recommendation": "可以直接继续",
  "passed": true,
  "jobMessages": ["正在整理声音片段", "正在保留声音特点", "正在准备试听版本"],
  "seedKind": "seed",
  "previewResourceName": "voice_phrase_mom"
}
```

### 拒绝授权
输入：`authorized=false`  
输出：不可进入处理步骤（本地校验）。

### 加速定时
输入：`TimerOption.demoAccelerated`（仅 Debug/演示控制可见）  
输出：约 45s 内完成分层渐隐；正式 10/30/60 分钟选项保留真实时长逻辑。

### 音频缺失回退
输入：资源文件不在 Bundle  
输出：该轨静音，其余轨继续；`PlaybackService` 报告可恢复错误，不崩溃。

## 5. 持久化

- Schema version：`1`
- 键前缀：`dw.demo.v1.*`
- 持久化：当前场景 ID、个人混音快照、收藏、声音库变更、陪伴记录、设置
- `resetDemoState()`：恢复 Bundle 夹具 + 清空用户编辑

## 6. 赛后演进映射

| 当前 | 赛后 |
|------|------|
| Bundle JSON | `GET /v1/scenes` 等 |
| 预录制种子产物 | 上传 + 异步 Job + CDN |
| 本地 UsageRecord | 本地优先 + 可选云同步 |
| 本地资源名 | 签名 URL / 对象存储键 |
| 演示登录布尔 | Sign in with Apple 服务端校验 |

## 7. 明确不声称已实现

真实声音克隆、在线收听人数、后台/锁屏完整播放、医学级睡眠分析、云同步、付费订阅。
