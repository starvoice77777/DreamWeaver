# 织梦 · 前后端协作说明（给双方）

> 写给：前端同学 + 后端同学  
> 前提：我们都是第一次认真用 Git 协作，这份文档尽量只讲「要做什么、别做什么」。  
> 仓库：https://github.com/starvoice77777/DreamWeaver  
> 更新日期：2026-07-31  
> Agent 约束：仓库内 `.cursor/rules/`（双方用 Cursor Agent 时自动生效）

---

## 0. 双方都用 Agent 时多注意什么

人读本文档；**Agent 主要靠 Cursor Rules**，不会自动读完整篇 Markdown。

| 给谁 | 放哪里 | 作用 |
|------|--------|------|
| Agent（推荐） | `.cursor/rules/*.mdc` | 改代码时自动提醒分工、危险区、冲突原则 |
| 人 | 本文档 | 分支流程、沟通模板、检查清单 |
| 偶尔用的流程 | 可选 Skill | 例如「如何合对方分支」逐步操作（非必须） |

**请双方把含 `.cursor/rules/` 的仓库拉到本地**，并用同一集成分支联调。只把文档发给对方、却不同步 rules，Agent 仍可能乱改危险区。

让 Agent 干活时，建议在提示里写清角色，例如：

- 「你是前端 Agent：只改 Views/DesignSystem，危险区先问我」
- 「你是后端 Agent：优先改 Services/server，保留前端 mix palette 逻辑」

---

## 1. 一句话分工

| 角色 | 主要负责的目录 | 尽量少改 |
|------|----------------|----------|
| **前端** | `DreamWeaver/Views/`、`DreamWeaver/DesignSystem/`、页面交互与视觉 | `server/`、`infra/`、`Services/` 里的播放与持久化实现 |
| **后端** | `server/`、`infra/`、`docs/`（技术方案）、`DreamWeaver/Services/`、`DreamWeaver/Models/` 中与数据/播放相关的部分 | 页面布局、动画、控件样式 |

**两边都会碰到的“危险区”（改之前必须先说一声）：**

- `DreamWeaver/App/AppState.swift`（全局状态，前后端最容易撞车）
- `DreamWeaver/Models/`（尤其是 `AppEnums.swift`、`DreamScene.swift`、`SoundAsset.swift`）
- `DreamWeaver/Views/Now/SoundMixCircleEditor.swift`（圆盘：前端交互 + 后端音频资源）
- `DreamWeaver/Views/Now/NowView.swift`（播放页）

约定：**谁先改危险区，先在群里发一句「我要改 XXX，大概改什么」；改完 push 后发分支名 + commit。**

---

## 2. 当前仓库里有哪些分支（先认门牌）

| 分支 | 含义 | 谁用 |
|------|------|------|
| `main` | 正式主干，**不要直接在上面改代码** | 只通过 PR 合入 |
| `feat/frontend-update` | 前端页面更新分支 | 前端日常开发可基于此 |
| `feat/demo-backend` | 后端：本地播放、Service、`server` 脚手架 | 后端单独开发用 |
| `integration/frontend-backend` | **已合并：前端页面 + 后端能力**，当前推荐联调分支 | 双方一起测、一起改冲突后的结果 |

当前推荐联调起点：

```text
integration/frontend-backend
```

远程地址示例：

```text
https://github.com/starvoice77777/DreamWeaver/tree/integration/frontend-backend
```

---

## 3. 每天开工前（两边都做）

在项目根目录打开终端（Mac 用 Terminal / Cursor；Windows 用 PowerShell），执行：

```bash
git status
git fetch origin
```

看两件事：

1. `git status` 是否干净（有没有未提交的改动）  
2. 自己是否在正确的分支上

如果有未提交的改动，**先提交或先问对方**，不要急着换分支或合并。

---

## 4. 推荐日常流程（照着做）

### 4.1 前端要改页面时

1. 从最新集成分支拉出自己的小分支（名字自定，建议带名字或日期）：

```bash
git fetch origin
git switch integration/frontend-backend
git pull origin integration/frontend-backend
git switch -c feat/ui-xxxx
```

2. 改 Views / DesignSystem，尽量少动 `AppState`。  
3. 本地 Xcode 能编译、自己点一遍主要页面。  
4. 提交并推送：

```bash
git add .
git status
git commit -m "简述你改了什么，例如：调整此刻页定时弹层样式"
git push -u origin feat/ui-xxxx
```

5. 在群里告诉后端：  
   - 分支名  
   - 改了哪些文件（尤其有没有碰 `AppState`）  
   - 让后端帮忙合进 `integration/frontend-backend`，或自己开 PR

### 4.2 后端要改服务 / 播放 / 接口时

1. 同样建议基于集成分支开小分支：

```bash
git fetch origin
git switch integration/frontend-backend
git pull origin integration/frontend-backend
git switch -c feat/api-xxxx
```

2. 优先改：`Services/`、`server/`、`Models/`（数据字段）。  
3. 若必须改 `AppState`，先在群里说。  
4. 提交、push、通知前端「有没有影响 UI」。

### 4.3 把对方的改动合进来（最重要）

假设前端推了 `feat/ui-xxxx`，后端要合进集成分支：

```bash
git fetch origin
git switch integration/frontend-backend
git pull origin integration/frontend-backend
git merge origin/feat/ui-xxxx
```

- 若提示冲突：先别慌，打开冲突文件，搜 `<<<<<<<`  
- 冲突解决后：

```bash
git add .
git commit -m "Merge feat/ui-xxxx into integration"
git push origin integration/frontend-backend
```

**原则：合别人的代码前，自己的工作区必须是干净的（已提交）。**

---

## 5. 冲突怎么处理（新手版）

冲突文件里会出现：

```text
<<<<<<< HEAD
这边是你当前分支的代码
=======
这边是对方分支的代码
>>>>>>> 对方分支名
```

处理步骤：

1. 打开文件，理解两边各自想保留什么  
2. **手工拼成一份正确代码**（删掉 `<<<<<<<` / `=======` / `>>>>>>>` 这三行标记）  
3. 保存 → `git add 该文件` → 全部冲突解决后 `git commit`

### 5.1 我们上次整合时的约定（可继续沿用）

| 情况 | 留谁的 |
|------|--------|
| 页面布局、动画、控件显隐、圆盘手势 | **前端** |
| 真正播放、定时器、本地 Service、`server/` | **后端** |
| 已删除的旧页（如 `SceneDetailSheet`、`ScenePreviewView`） | **按前端：不要恢复** |
| `AppState` | **两边都要**：前端交互方法 + 后端 `playback` / Service 调用 |

拿不准时：**先保留两边逻辑，编译不过再一起改**；不要直接整文件「全部用我的」。

---

## 6. 沟通模板（直接复制）

### 我改完了，请你同步

```text
【同步请求】
分支：feat/ui-xxxx
主要改动：此刻页定时弹层 / 场景库卡片
是否改了 AppState：否 / 是（说明改了哪些方法）
请你：合进 integration/frontend-backend 后告诉我一声
```

### 我要改危险区

```text
【预告】
我准备改 AppState.swift / SoundMixCircleEditor.swift
目的：……
预计今天改完，请暂时别改同一文件
```

### 合并出冲突了

```text
【冲突求助】
文件：AppState.swift
我这边想保留：……
你那边想保留：……
方便语音/截图一起看 10 分钟吗？
```

---

## 7. 绝对不要做的事

1. **不要在 `main` 上直接开发、直接 push**  
2. **不要 `git push --force`**（除非两人当面确认，且绝不对 `main` 强推）  
3. **不要 `git reset --hard`**（会丢掉未提交改动）  
4. **不要在有未提交改动时乱切换分支**  
5. **不要提交密钥文件**：`server/.env`、密码、证书（仓库已忽略 `.env`，只提交 `.env.example`）  
6. **不要私自恢复前端已删除的旧页面**（`SceneDetailSheet` 等）  
7. **不要假设「我 pull 一下就好」**——对方分支名要说清楚，并合到约定的集成分支

---

## 8. 提交信息怎么写

短一点、说清楚「为什么 / 改了什么」即可，中英文都行，例如：

- `调整此刻页控件显隐，避免与调色盘抢焦点`
- `Add sleep timer wiring to LocalPlaybackService`
- `Merge feat/ui-timer into integration`

一次提交尽量只做一类事（别把「改 UI + 改后端数据库」塞进同一个 commit）。

---

## 9. 联调检查清单（合完对方代码后）

在 Mac / Xcode 上至少点一遍：

- [ ] 工程能编译  
- [ ] 启动后能进「此刻」并听到声音（有音频资源的场景）  
- [ ] 场景库点卡片 → 直接进入「此刻」  
- [ ] 圆盘：拖动、增删声源、播放不整段卡死重启  
- [ ] 收藏按钮可用  
- [ ] 定时选项正常；「演示加速」仅在设置打开演示控制时出现  
- [ ] 没有误把已删页面又加回来  

后端另加：

- [ ] `server` 本地健康检查仍可通过（若这轮没动 server，可跳过）

---

## 10. 产品相关共同约定（避免各改各的）

以下已产品确认，前后端都按这个做（细节见 `docs/production-backend-architecture-and-roadmap.md` 第 15 节）：

- 底部 Tab 为产品信息架构；「此刻」是播放页能力，不是旧的预览 Sheet 流程  
- 点场景卡片 → 直接进入「此刻」  
- 混音需要**显式保存**才算保存  
- 定时：自动 / 10 / 30 / 60 / 一直；「演示加速」仅演示/调试  
- 旧的 `SceneDetailSheet` / `ScenePreviewView` 不再使用  

---

## 11. 文件归属速查（改之前看一眼）

| 路径 | 默认负责人 | 备注 |
|------|------------|------|
| `Views/` | 前端 | 后端只在接服务时最小改动 |
| `DesignSystem/` | 前端 | |
| `App/RootTabView.swift` | 前端为主 | 与闲置回「此刻」相关时后端可协助 |
| `App/AppState.swift` | **共同** | 改前必沟通 |
| `Models/` | **共同** | 新增字段要告诉对方 |
| `Services/` | 后端 | 前端一般只调用，不改实现 |
| `Resources/Audio/` | 后端 / 素材负责人 | |
| `server/`、`infra/` | 后端 | |
| `docs/` | 后端整理为主 | 协作文档双方都可改 |

---

## 12. 第一次把集成分支拉到自己电脑

```bash
git fetch origin
git switch integration/frontend-backend
# 若本地还没有该分支：
# git switch -c integration/frontend-backend origin/integration/frontend-backend

git pull origin integration/frontend-backend
```

然后用 Xcode 打开 `DreamWeaver.xcodeproj`，选模拟器编译运行。

---

## 13. 出了问题怎么办（最短路径）

1. 先发：当前分支名、`git status` 截图、报错原文  
2. **先不要 force push / reset --hard**  
3. 如果只是「想暂时放下本地改动」：可以先 `git stash`（或新建一个 backup 分支提交），再问对方  
4. 冲突超过 15 分钟搞不定：两人对着同一个文件看，比各自闷头改更快  

---

## 14. 我们希望形成的习惯

1. 小步提交、常推送，不要攒几天一次大合并  
2. 危险区先预告  
3. 合完代码互相说一声「已合进 integration，请 pull」  
4. 能编译、能点通主路径，再喊对方继续往下做  

有疑问先问，比改错再恢复便宜得多。
