# 洗头陪伴场景（sc_hair_wash_v05 / 时间线 v11）

> 真相源：`docs/scenes/sc_hair/packages/sc_hair_wash_v05_review/scene/timeline.json`
> 工程输出：后端与 iOS 各一份 `hair_care_timeline_v11.json`，由 `server/scripts/build_hair_care_timeline_v11.py` 生成。

## 当前实现

| 项 | 说明 |
|----|------|
| 总时长 | 620 秒（约 10:20） |
| 时间线 | version **11**；138 个 cue，含 106 次 `set_position`、54 次 `set_envelope`、20 次 `play_phrase`、10 次 `play_oneshot` |
| 轨清单 | 9 条环境/动作轨 + 20 条逐句人声轨；客户端映射为 9 个非人声节点和 1 个复用的人声空间节点 |
| 人声 | `voice_phrase_01`…`voice_phrase_20`，逐句动态换源；短句状态保留为 `qc_pending` |
| 空间/响度 | 圆盘半径决定用户感知距离增益；`set_envelope` 仅保留为剧情淡入淡出和 ducking 自动化，不是用户音量旋钮 |
| 双端 | 本地模式读 iOS Bundle fixture；远程模式由 `GET /v1/scenes/{id}/timeline` 返回同一文档 |

已有数据库中的洗头陪伴时间线若 `version < 11` 会自动升级。catalog 复用既有稳定 UUID，因此收藏、预设与私人场景引用无需迁移。

## 引擎节点映射

| 引擎 UUID 后缀 | 资源键 | 播放语义 |
|---|---|---|
| `…506` | `water_drip_roomtone` | trigger / 两次 oneshot |
| `…508` | `hair_wash_water_cycle` | environment / loop |
| `…509` | `hair_wash_wet` | trigger / oneshot |
| `…50A` | `hair_wash_foam_start` | trigger / oneshot |
| `…50B` | `hair_wash_foam_rub` | ambience / loop |
| `…50C` | `hair_wash_scalp_foam` | ambience / loop |
| `…50D` | `hair_wash_rinse` | trigger / oneshot |
| `…50E` | `hair_wash_finger_massage` | ambience / loop |
| `…50F` | `hair_towel` | trigger / oneshot |
| `…503` | `voice_phrase_01`…`20` | voice / 每句动态换源 |

外部包中的 20 个 voice track UUID 都映射到 `…503`。每个 phrase 仍保留独立 UUID、文本和资源键，`play_phrase` 执行时由 `voice_binding.resource_key` 选择对应 WAV。

## 审核与发布边界

该交付包版本为 `0.5.0-review`，状态是 `review_ready_qc_pending`、`demo_ready=true`、`release_ready=false`。当前接入仅用于开发联调与演示，不能据此宣称素材可正式分发。

发布前仍需完成：

- 20 条人声的声线授权、逐句内容/语气试听与响度验收；
- 非人声参考素材的来源凭证和授权范围确认；
- 手机外放、耳机、loop 连续性以及路径安全实机验证；
- 根据最终母带决定是否做包体转码，且重新运行完整音频 QC。

完整状态、问题清单与许可证见归档包内 `scene/scene_manifest.json`、`qc/`、`licenses/` 和 `INGEST.md`。

## 维护与验证

1. 修改归档包的 `scene/timeline.json` 或资源映射。
2. 运行 `server/.venv-codex/Scripts/python.exe server/scripts/build_hair_care_timeline_v11.py`。
3. 确认后端与 iOS fixture 哈希一致。
4. 运行后端测试，并在 Mac/Xcode 真机检查全部 20 句与动作声的入点、空间位置和结尾淡出。

不要直接手改两份生成后的 fixture，以免双端漂移。
