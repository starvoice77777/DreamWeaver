# rain_bamboo_leaf v2 处理与 QC 报告

## 定位与问题

- 原文件：`dw_official_amb_rain_bamboo_leaf_loop_sc_rain_soft_v01_t01.wav`
- 该声音是竹叶受雨的细节层，应晚于远雨和近檐雨进入，不得盖过 `rain_parasol`。
- 原始响度约 `-20.32 LUFS`（FFmpeg）且动态变化较大，高频能量明显，直接叠加容易抢注意力。

## 处理目的

1. 推荐自然版整体降低 3.2 dB，使响度进入约 `-23～-24 LUFS` 的细节层范围。
2. 另保留轻微削亮版：只在 6.5 kHz 以上轻降约 1.5 dB，避免整体雨丝被削薄。
3. 6.05 秒素材较短，另生成 32.30 秒演示版，内部以 800ms 等功率交叉淡化连接。

## 输出与实测

| 文件 | 用途 | 时长 | 综合响度 | 真峰值 | 说明 |
| --- | --- | ---: | ---: | ---: | --- |
| `dw_official_amb_rain_bamboo_leaf_loop_sc_rain_soft_v02_t01.wav` | 推荐自然降响版 | 6.050s | `-23.52 LUFS` | `-6.19 dBTP` | 保留高频雨丝，推荐先用于混音 |
| `dw_official_amb_rain_bamboo_leaf_loop_sc_rain_soft_v02_t02.wav` | 轻微削亮备选 | 6.050s | `-23.57 LUFS` | `-6.16 dBTP` | 高频更柔，只在人工试听确认尖锐时采用 |
| `dw_official_amb_rain_bamboo_leaf_loop_sc_rain_soft_v02_t03.wav` | 复赛演示长版 | 32.300s | `-24.33 LUFS` | `-6.19 dBTP` | 六段 t01 以 800ms 等功率交叉淡化连接 |

三条均为 48 kHz、双声道、PCM 16-bit WAV；未覆盖原始文件。

## 时间线建议

- 播放区间：`3:40–8:50`，默认 `volume=0.27`，`angle=-1.00 rad`，`radius=0.78`。
- t01 使用 `loop=true`、`requires_engine_crossfade=true`、`crossfade_ms=800`。
- 3:40 用 10 秒淡入，8:40 起 10 秒淡出；不与开场其他轨同时出现。
- 若与主雨声叠加后仍突出，优先把时间线 `volume` 从 0.27 调到 0.23–0.25；不要再次破坏母带响度。

## 必须人工试听

1. 耳机比较 t01/t02，重点听是否有尖锐竹叶拍击、齿状高频或疲劳感。
2. 手机外放确认竹叶纹理可感知但不会成为主声源。
3. t01 连续循环至少 2 分钟，检查 800ms 交叉淡化是否形成周期性起伏。
4. t03 完整试听，确认五个连接点和短素材重复纹理可接受。

正式上架前建议换为 30–90 秒以上长母带；当前状态保持 `qc_pending`。
