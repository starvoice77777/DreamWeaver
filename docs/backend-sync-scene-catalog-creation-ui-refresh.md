# 场景目录与创建体验改版：后端同步说明

## 1. 分支与基线

- 功能分支：`codex/scene-catalog-creation-ui-refresh`
- 基线：`origin/integration/frontend-backend` 的 `d1c1935`
- 交付方式：请合并功能分支，不要从开发者本地联调分支拣选未提交文件。
- 数据库结构：没有新增或修改表结构，因此没有 Alembic schema migration。

## 2. 本次改动范围

本次提交同时包含 iOS 场景目录、场景图片、创建页交互、全局视觉系统与官方 catalog 数据更新。后端需要关注的代码集中在：

- `server/app/services/seed_catalog.py`
- `server/app/services/content.py`
- `server/tests/test_content_api.py`
- `server/README.md`

iOS 侧的场景 UUID 保持稳定；场景改名不会让用户收藏、最近播放、预设绑定或私有场景来源引用失效。

## 3. 官方场景目录变化

官方目录由 14 个场景调整为 13 个。以下场景复用原 UUID，并更换名称、文案、图片与客户端枚举名称：

| UUID 后缀 | 原场景 | 新场景 | API `visual_style` | iOS 枚举 |
| --- | --- | --- | --- | --- |
| `1103` | 深林萤火 | 喜马拉雅 | `fireflies` | `.himalaya` |
| `1104` | 雾岸听潮 | 星期天 | `mistTide` | `.mistTide` |
| `1106` | 月下静湖 | 山色 | `moonLake` | `.moonLake` |
| `1108` | 暖灯陪伴 | 长路 | `warmLamp` | `.longRoad` |
| `110A` | 风过麦田 | 麦浪 | `wheatWind` | `.wheatWave` |
| `110B` | 云间呼吸 | 飞行 | `cloudBreath` | `.flight` |
| `110C` | 夏夜虫鸣 | 夏夜 | `summerInsects` | `.summerNight` |

兼容原则：后端 `visual_style` 字符串没有随产品名称改动。iOS 通过显式 raw value 映射到新的枚举名称，因此旧数据库、旧缓存和远端响应仍可正常解码。

### 退役场景

- UUID：`a1111111-1111-4111-8111-11111111110e`
- 名称：流光溢彩
- 后端行为：加入 `RETIRED_SCENE_IDS`；已有数据库中的记录会被设置为 `is_published = false`。
- API 行为：不再出现在 `GET /v1/scenes`，访问 `GET /v1/scenes/{id}` 返回 404。
- iOS 行为：`emotionalFluid` 渲染器继续保留为可复用视觉能力，但不再作为官方场景展示。

## 4. API 与数据兼容性

接口字段结构没有变化。需要注意以下行为变化：

1. `GET /v1/bootstrap` 和 `GET /v1/scenes` 返回 13 个官方场景。
2. 若用户保存的默认场景已经退役，bootstrap 会回退到 `DEFAULT_SCENE_ID`（洗头陪伴）。
3. 顶层 `default_scene_id` 与 `settings.default_scene_id` 会返回同一个有效 ID，避免客户端状态不一致。
4. `ensure_official_catalog()` 会自动下架退役场景，但不会在 production 请求路径中覆盖所有现有官方场景元数据。
5. 场景音轨、预设、用户收藏关联继续使用原 UUID，不需要迁移外键。

## 5. Catalog 刷新方式

### 开发与测试环境

开发环境默认会在 API 启动时执行官方 catalog reseed。也可以显式调用：

```bash
curl -X POST http://127.0.0.1:8000/v1/admin/reseed-catalog
```

或者在 `.env` 中临时设置：

```dotenv
DW_FORCE_RESEED_CATALOG=true
```

刷新会 upsert 官方场景元数据、音轨和预设，并刷新官方时间线；不会删除孤儿音轨。

### 生产环境

`POST /v1/admin/reseed-catalog` 在 production 固定返回 403，`DW_FORCE_RESEED_CATALOG` 也会被忽略。上线前请后端通过受控的一次性部署任务调用 `reseed_official_catalog(session)`，或提供等价的数据迁移：

1. 更新表中上述稳定 UUID 对应的名称、文案、分类、标签与 palette。
2. 将 `...110e` 的 `is_published` 设为 `false`。
3. 保持 `visual_style` 为表格中的兼容字符串。
4. 不要删除旧场景行，避免破坏用户收藏、默认场景和私有场景来源引用。

即使没有执行完整 reseed，部署后的普通 API 请求也会自动下架 `...110e`；但其他场景的新名称和 palette 需要完整 reseed 或数据迁移才能进入已有 production 数据库。

## 6. iOS 改动摘要

- 替换并新增多张沉浸式场景图片，删除已退役的旧场景图片与专用 backdrop。
- 首页、创建页和个人页共享同一持续存在的场景背景，跨 Tab 时以模糊、缩放和暗化完成过渡。
- 底部导航可在空闲后收拢为当前页面图标，并支持左右停靠。
- 构件强调色统一为中性雾银灰，不再按场景动态跳色。
- 创建页入口、圆盘、顶部控制、时间轴和文本编排界面完成精简与统一。
- 声音选择弹窗改为一级分类纵向排列、分类内声音横向滑动；分类只显示图标，声音使用圆形图标和下方名称。
- 声音库并入创建流程下的“管理已有声音”，并统一去除非必要液态玻璃效果。
- 首页进度条支持直接拖动，并采用更大的品牌化拖动标记。
- 场景选择入口、收藏按钮、标签与图标规格统一。

以上 UI 改动不新增 API 字段。

## 7. 合并热点

后端合并时请重点检查以下共享文件：

- `DreamWeaver/App/AppState.swift`：仅调整新场景枚举与预设的对应关系。
- `DreamWeaver/Services/APIContentDTO.swift`：未知 `visual_style` 的客户端回退改为 `.longRoad`。
- `server/app/services/seed_catalog.py`：官方目录内容、13 场景计数与退役场景逻辑。
- `server/app/services/content.py`：退役默认场景的 bootstrap 回退与嵌套 settings 一致性。

## 8. 本分支验证结果

- iOS 完整无签名 Debug 构建（包含 Asset Catalog）：通过。
- 全部 Swift 文件语法检查：通过。
- Asset Catalog JSON 校验与场景图片格式检查：通过。
- Server pytest：54 项通过。
- 修改涉及的 Python 文件 Ruff：通过。
- `git diff --check`：通过。

仓库现有 Alembic 历史文件仍存在既有 Ruff 格式告警；本次未改动这些 migration 文件，也未将其纳入改动范围。

## 9. 后端验收清单

- [ ] `/v1/scenes` 不返回 `...110e`。
- [ ] `/v1/scenes/...110e` 返回 404。
- [ ] 新目录名称、标签和 palette 与 `official_scene_specs()` 一致。
- [ ] `visual_style` 仍使用兼容字符串，没有改成新的 iOS 枚举名称。
- [ ] 退役场景原本作为默认场景的用户可正常回退到洗头陪伴。
- [ ] 用户收藏、预设和私有场景来源引用没有因为目录改名而丢失。
- [ ] production 已执行受控 catalog reseed 或等价数据迁移。
