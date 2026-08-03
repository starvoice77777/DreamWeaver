# 前端交接：场景创作 Composition（后端先行）

> 同步分支目标：`feat/scene-composition-v1` → `integration/frontend-backend`  
> 正式契约：[scene-composition-contract.md](./scene-composition-contract.md)

## 产品结论（已对齐）

- 取消语音克隆；Seed 入口请隐藏。
- 新增「创建」：底部中间 **创建 Tab**（不嵌「此刻」）。
- 一期关键帧：**轨上点选多帧** + **游标插入**；画布拖动改**当前选中帧**。
- 关键帧间连续路径由客户端插值；**允许过圆心**；不做禁区校验。
- 官方 cue/phrase 时间线保留；用户创作用 `scene_composition_v1`。

## 后端将提供的字段 / API

私人场景详情增加：

- `draft_composition`
- `saved_composition`

| 方法 | 路径 | 说明 |
|------|------|------|
| PUT | `/v1/users/me/scenes/{id}/draft` | body 可含 `draft_composition` |
| POST | `/v1/users/me/scenes/{id}/save` | 快照 composition（先校验） |
| GET | `/v1/users/me/scenes/{id}` | 带回 draft/saved composition |
| POST | `/v1/compositions/validate` | 仅校验 |

JSON 形状与插值公式见契约文档 §3–§5。

## 前端可先做

- 创建 Tab + 时间轴/关键帧 UI（Mock `scene_composition_v1`）
- 隐藏 Seed / 声样克隆入口
- 插值预览按契约实现

## 建议等后端合入再接

- Remote 读写 composition
- validate API
- `APIContentDTO` 新字段

## 危险区

`RootTabView`、新 Create 流、若复用则 `SoundMixCircleEditor` / `AppState` — 改前与后端停改同步。
