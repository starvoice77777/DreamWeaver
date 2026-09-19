# DreamWeaver 结构脚本注册表 v1

本目录把五种声音组合方式转换为可版本化、可校验、可交给确定性编译器执行的结构脚本。它补齐 `integration/frontend-backend` 在 AI 生成迁移说明中记录的 `ScriptRegistry` 缺口，但不替代内容预设、素材绑定、运动预设或最终时间线编译器。

## 文件

- `structure-script.schema.json`：单个结构脚本的公共 JSON Schema。
- `script-registry.json`：固定顺序、脚本 ID、框架 ID、版本和文件路径。
- `scripts/01...05_*.json`：五类结构脚本。
- `tools/validate_structure_script_registry.py`：无第三方依赖的工程校验器。
- `tests/test_structure_script_registry.py`：注册表、参数域、数量预算、保护规则和安全语义测试。

## 固定顺序

| 顺序 | 用户名称 | `framework_id` | `script_id` |
| --- | --- | --- | --- |
| 1 | 内外交织 | `boundary_gate` | `boundary_gate_script` |
| 2 | 安稳包围 | `enclosure_control` | `enclosure_control_script` |
| 3 | 远近分层 | `depth_reveal` | `depth_reveal_script` |
| 4 | 主声突出 | `focus_selector` | `focus_selector_script` |
| 5 | 两侧舒展 | `nearfield_width` | `nearfield_width_script` |

## 设计边界

每个脚本负责：

1. 定义结构槽位以及允许的区域、角色和播放类别；
2. 校验请求为一至四个用户声音；
3. 将最终场景约束为一个底层、零至一个环境层、零至三个前景对象，且总数不超过四个；
4. 把控制器状态解析为已审核内容或运动配置的引用；
5. 保护用户锁定对象和 `manual_override_track_ids`；
6. 按固定六阶段流程生成 `SceneDraft`，再交给确定性时间线编译器。

脚本不负责：

- 直接选择未审核素材；
- 写入具体 `resource_key`；
- 生成 `cues`、`at_seconds`、任意角度、半径或音量；
- 修改用户已经手动编辑的轨道；
- 把“系统补充声音”伪装成用户选择。

## 数量解释

请求契约允许用户选择 `1..4` 个逻辑声音对象。最终第二层场景必须满足：

```text
bed = 1
ambience = 0..1
foreground = 0..3
1 <= ambience + foreground <= 3
2 <= total <= 4
voice <= 1
```

当用户选择不足以填满某个脚本的必需槽位时，只能返回澄清，或显式加入 `origin=system_supplement`、具有 `approved` 绑定并附带原因的补充对象。被用户删除的声音不得静默加回。

## 状态与发布

当前五个脚本均为：

- `execution_status=implementation_ready`：结构和字段可供后端接线；
- `review_status=pending_listening_review`：尚未完成耳机、手机外放和长时试听冻结。

后端正式注册表只能加载 `review_status=approved` 的版本。审核升级必须递增脚本版本，不能原地覆盖已经进入缓存键或生成日志的版本。

## 校验

使用工作区 Python 运行：

```powershell
python tools/validate_structure_script_registry.py "docs/现行工作集/02_辅助创建与视觉框架/结构脚本注册表_v1"
python -m unittest tests.test_structure_script_registry -v
```

校验器除结构检查外，还会拒绝脚本内出现由编译器拥有的字段，如 `cues`、`at_seconds`、`angle`、`radius`、`default_volume` 和 `resource_key`。
