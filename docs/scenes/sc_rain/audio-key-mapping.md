# 音频短键：檐下听雨母带映射

已交付母带可本地演示使用；当前状态为 `qc_pending`。进入正式 Bundle / 上架前须完成循环验收与许可证登记。

| resource_key | 规范母带文件 | 原始文件 | 听感用途 | 处理备注 |
| --- | --- | --- | --- | --- |
| `rain_parasol` | `dw_official_env_rain_parasol_loop_sc_rain_near_v01_t01.wav` | `Close-up_gentle_rain_#4-….wav` | 近雨 / 檐面主环境 | 循环；若首尾不闭环需引擎 crossfade |
| `rain_soft` | `dw_official_amb_rain_soft_loop_sc_rain_far_v01_t01.wav` | `Indoor_perspective_o_#2-….wav` | 室内远雨垫底 | 循环；若首尾不闭环需引擎 crossfade |
| `rain_bamboo_leaf` | `dw_official_amb_rain_bamboo_leaf_loop_sc_rain_soft_v01_t01.wav` | `Soft_rainy_bamboo_fo_#3-….wav` | 竹叶雨细腻氛围层 | 循环；音量须低于近雨/远雨 |
| `wind_realistic` | `dw_official_env_wind_realistic_loop_sc_rain_far_v01_t01.wav` | `audiomass-output (5).wav` | 远风短段进入 | 循环素材；脚本仅 3:00–3:20、7:30–7:50 启用 |

技术：48kHz 立体声 WAV；轻度处理、无激进降噪/固定降频；为保留可循环性未做首尾人工淡入淡出。
