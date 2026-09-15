# Dream Weaver

Dream Weaver 是一个 iOS 17+ 的 SwiftUI 睡眠声音场景 Demo。它把声音卡片拖入一张沉浸式梦境画布，按声音分类自动生成背景、氛围、主体和动态视觉层；当前版本只做场景编排和预览，不播放真实音频。

## 项目结构

- `Models/`：声音元素、声音分类、槽位类型及场景状态模型。
- `Stores/SceneComposer.swift`：放置校验、替换、移除、清空和示例场景等编排逻辑。
- `Views/`：沉浸式画布、场景标题栏、声音调色板、声音卡片和动态视觉层。
- `SleepSceneDemoTests/`：`SceneComposer` 的匹配、分类校验、替换、示例和清空测试。

## 系统要求与运行

- 最低系统：iOS 17.0。
- 使用 Xcode 打开 `SleepSceneDemo.xcodeproj`，选择 `SleepSceneDemo` scheme 和 iOS 模拟器或真机，然后 Run（⌘R）。
- 命令行构建（不签名）：

  ```sh
  xcodebuild -project SleepSceneDemo.xcodeproj -scheme SleepSceneDemo \
    -sdk iphonesimulator -configuration Debug build CODE_SIGNING_ALLOWED=NO
  ```
- 运行测试（需要已安装并可用的 iOS Simulator runtime/device）：

  ```sh
  xcodebuild test -project SleepSceneDemo.xcodeproj -scheme SleepSceneDemo \
    -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO
  ```

## 操作路径

1. 上方是沉浸式梦境画布，下方是声音调色板。长按并拖动一张声音卡片到画布任意位置即可加入场景；投放位置只代表加入动作，不代表声音的空间位置。
2. 若设备不便拖拽，先点击卡片使其选中，再点击画布完成放置。画布会按声音的默认分类自动生成背景、氛围、主体、细节或动态视觉层。
3. 声音标签会显示在画布上方，点击标签可以移除对应声音。底部面板支持分类筛选、横向浏览和上拉展开。
4. “加载示例场景”会填入 Rain（氛围）、Fireplace（主体）和 Page Turning（细节），形成“雨夜壁炉”示例；“清空画布”会移除全部声音并回到空画布。

## 预览与范围

舞台预览覆盖空场景和已组合场景：Rain 显示雨丝，Fireplace/Campfire 显示火光，Page Turning、Footsteps、Clock 和 ASMR 会显示对应图标。当前范围不包含音频资源、真实播放、混音、循环和后台音频；顶部播放按钮仅切换 Demo 的播放状态。

## 后续扩展建议（优先级）

1. **高**：接入本地或远程音频资源，建立播放/暂停、循环和音量混音层，并让 `isPlaying` 驱动真实播放器。
2. **中**：为槽位和卡片增加持久化（SwiftData 或文件存储），恢复最近场景并支持分享/导出。
3. **中**：补充更完整的可访问性和拖放反馈，包括 VoiceOver 操作、动态字体和错误状态的 UI 测试。
4. **低**：扩展声音目录、支持多套主题与自定义槽位规则，并加入计时器或睡眠模式。
