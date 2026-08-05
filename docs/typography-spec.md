# DreamWeaver 字体规范 v1.0

更新日期：2026-08-05  
适用范围：DreamWeaver iOS 客户端（深色沉浸页面、创建工具、声音库、个人与设置页面）

## 1. 字体策略

DreamWeaver 的文字应当安静、清晰、克制。字体不承担装饰主体，而是帮助用户在睡前低注意力状态下快速理解当前场景和操作。

- 中文正文统一使用随 App 打包的思源黑体简体中文版（Source Han Sans CN VF）。
- 英文与数字统一使用 San Francisco 系统字体。
- 不在正文中混用第三方中文字体，避免字重缺失、动态字体失效和安装包增大。
- 品牌英文 `DreamWeaver` 可使用系统 Serif，作为有限的品牌点缀。
- 时间、时长和时间轴刻度使用系统 Monospaced，避免数字变化时宽度跳动。
- 场景名称允许轻字重和较大字号；操作按钮、表单和长正文不使用 Light 或 Ultra Light。
- 普通中文信息不低于 12pt；8–10pt 仅允许出现在空间有限的时间轴刻度和图内标注中。

## 2. 推荐字体族

### 当前落地方案

| 内容 | SwiftUI 字体 | 说明 |
|---|---|---|
| 中文正文 | `.custom("Source Han Sans CN VF", ...)` | 思源黑体简体中文可变字体，统一产品气质 |
| 英文与数字 | `.system(...)` | 使用 SF Pro，与 iOS 控件一致 |
| 品牌英文 | `.system(..., design: .serif)` | 仅用于 `DreamWeaver` 等短品牌文字 |
| 时间与数值 | `.system(..., design: .monospaced)` | 用于倒计时、时间轴、音频起止时间 |
| 强调数字 | `.system(..., design: .rounded)` | 可用于录音时长、倒计时主数字，避免用于正文 |

字体文件随 App 打包并在 `Info.plist` 注册；语义 Token 使用 `relativeTo` 保留 Dynamic Type。英文品牌与纯数字时间码维持系统字体，以保证衬线品牌气质和等宽数字稳定性。

### 可选品牌方案

如果未来需要更强的东方、梦境气质，可仅为启动页或场景名称引入一款有完整商业授权的中文标题字体。建议选择笔画不过细、字面较大、具备 Regular/Medium 两档的字体。

不建议把手写体、宋体或高对比度衬线体用于按钮、设置项、声音库列表及时间轴。这些区域需要快速识别，装饰字体会降低深色背景下的可读性。

## 3. 语义字体层级

字号为当前默认内容尺寸下的视觉基准。实现时应优先绑定 Dynamic Type 文本样式，而不是永久固定字号。

| Token | 用途 | 基准字号 | 字重 | 设计 | 行高建议 |
|---|---|---:|---|---|---:|
| `dreamDisplay` | 首页场景名称、沉浸标题 | 34 | Light | Default | 41 |
| `largeTitle` | 独立流程大标题 | 28 | Light | Default | 34 |
| `pageTitle` | 创建、声音库、我的等页面标题 | 24 | Light | Default | 30 |
| `sectionTitle` | 创建场景、创建声音、陪伴记录 | 18 | Medium | Default | 24 |
| `cardTitle` | 场景卡片、声音资产名称、主要入口 | 16 | Medium | Default | 22 |
| `body` | 页面说明、主要正文 | 15 | Regular | Default | 22 |
| `callout` | 按钮标签、筛选标签、次级操作 | 14 | Medium | Default | 19 |
| `caption` | 状态、计时说明、卡片补充信息 | 12 | Regular | Default | 17 |
| `micro` | 紧凑编辑器标签 | 10 | Medium | Default | 13 |
| `timecode` | 倒计时、时间轴当前时间 | 12 | Medium | Monospaced | 16 |
| `brand` | `DreamWeaver` 品牌英文 | 23 | Light | Serif | 28 |

## 4. 页面使用规则

### 此刻

- 场景名称使用 `dreamDisplay`，建议由当前 34 Ultra Light 调整为 34 Light；中文 Ultra Light 在暗色动态背景上容易断笔。
- 场景描述使用 `body`，最多两行，建议行距 3–4pt。
- 当前计时状态使用 `caption`；倒计时数字使用 `timecode`。
- 播放、收藏等纯图标按钮不额外显示常驻文字，以辅助功能标签补足语义。

### 场景选择

- 页面标题使用 `pageTitle`。
- 分类 Tag 使用 `callout`；未选中 Regular，选中 Semibold。
- 螺旋卡片场景名称使用 `cardTitle`，描述使用 `micro` 或 `caption`，不要低于 10pt。

### 创建与声音库

- “创建场景”“创建声音”等组标题使用 `sectionTitle`。
- 主入口卡片标题使用 18 Medium，说明使用 13–15 Regular。
- 声音名称使用 `cardTitle`，时长与类型使用 `caption`。
- 关键操作可以使用 Medium/Semibold，但避免全页面大面积 Semibold。

### 空间编辑器与时间轴

- 编辑器的主要栏目使用 16–18 Medium。
- 当前时间使用 `timecode`。
- 轨道名称至少 10pt，建议提升至 11–12pt。
- 时间轴刻度可保留 8pt Monospaced，但必须保证高对比度，并只承载短数字。
- 9pt 的中文提示、按钮或状态应提升至至少 10pt，普通阅读内容提升至 12pt。

### 我的与设置

- 用户昵称使用 `pageTitle`。
- 数据值使用 16 Medium；数据名称使用 `caption`。
- 设置项标题建议使用 16 Regular/Medium，说明使用 13 Regular。
- 设置页优先采用系统 `.body`、`.callout`、`.footnote`，以获得完整 Dynamic Type 支持。

## 5. 字重规则

| 字重 | 使用范围 |
|---|---|
| Ultra Light | 仅可用于大于等于 40pt 的纯数字，不用于中文 |
| Light | 场景名称、页面大标题、品牌文字 |
| Regular | 正文、说明、未选中的筛选项 |
| Medium | 卡片标题、栏目标题、常规按钮 |
| Semibold | 当前选中态、确认操作、极短强调文字 |
| Bold 及以上 | 默认不使用；会破坏产品的安静气质 |

同一屏幕尽量不超过三种字重。不要仅依靠字重表达状态，应同时结合颜色、位置或图标。

## 6. 颜色与背景适配

- 主文字：`DreamTheme.moonWhite`。
- 次级文字：`DreamTheme.secondaryText`，适合 13pt 及以上。
- 三级文字：`DreamTheme.tertiaryText`，只用于非关键补充信息；小于 12pt 时应提高不透明度。
- 动态场景背景上的文字必须增加渐变遮罩或阴影，不能依赖极细字重解决层次。
- 暖杏色适合选中态和重要动作，不应用于长段正文。

## 7. Dynamic Type 与无障碍

- 页面标题、正文、按钮、设置项必须支持 Dynamic Type。
- 时间轴、二维声场等高密度工具可以限制放大范围，但需提供可访问性标签。
- 文本放大后，卡片高度应增长，禁止通过缩小字号或固定高度强行容纳。
- 标题最多限制两行；说明文字默认不截断，必要时使用 `.fixedSize(horizontal: false, vertical: true)`。
- 关键正文与背景建议达到至少 4.5:1 的对比度；大字号文字至少 3:1。

## 8. SwiftUI 落地建议

建议在 Design System 中增加语义 Token，页面不再直接散落 `.system(size:)`：

```swift
enum DreamTypography {
    static let dreamDisplay = Font.custom("Source Han Sans CN VF", size: 34).weight(.light)
    static let pageTitle = Font.custom("Source Han Sans CN VF", size: 24, relativeTo: .title2).weight(.light)
    static let sectionTitle = Font.custom("Source Han Sans CN VF", size: 18, relativeTo: .headline).weight(.medium)
    static let cardTitle = Font.custom("Source Han Sans CN VF", size: 16, relativeTo: .body).weight(.medium)
    static let body = Font.custom("Source Han Sans CN VF", size: 15, relativeTo: .body)
    static let callout = Font.custom("Source Han Sans CN VF", size: 14, relativeTo: .callout).weight(.medium)
    static let caption = Font.custom("Source Han Sans CN VF", size: 12, relativeTo: .caption)
    static let micro = Font.custom("Source Han Sans CN VF", size: 10, relativeTo: .caption2).weight(.medium)
    static let timecode = Font.system(size: 12, weight: .medium, design: .monospaced)
    static let brand = Font.system(size: 23, weight: .light, design: .serif)
}
```

第二阶段可逐步把固定字号替换为系统语义样式，例如 `.title2`、`.headline`、`.body`、`.callout` 和 `.caption`，并通过 `Font.custom(_:size:relativeTo:)` 为未来品牌字体保留 Dynamic Type 能力。

## 9. 当前项目优先整改项

1. 把首页场景名称从 34 Ultra Light 调整为 34 Light。
2. 把普通中文信息中的 9–10pt 提升到 12pt；时间轴内部标注可例外。
3. 将声音库、创建页、个人页重复出现的 12/13/14/15/16/18pt 收敛为语义 Token。
4. 统一所有时间显示为 Monospaced，避免倒计时跳动。
5. 为正文和按钮启用 Dynamic Type，固定字号优先只保留在沉浸标题和编辑器图内标注。
6. 删除没有明确语义差异的相邻字号，例如同类说明文字同时使用 11、12、13pt。
