# 檐下听雨 · 音频短键映射

| Bundle 短键 | 母带文件 | 用途 | 备注 |
|-------------|---------|------|------|
| `rain_soft` | `dw_official_env_rain_soft_loop_sc_rain_far_v02_t01.wav` | A01 远雨垫底 | 循环；引擎 crossfade ~1000ms |
| `rain_parasol` | `dw_official_amb_rain_parasol_loop_sc_rain_near_v02_t01.wav` | A02 檐下雨 / 近雨 | 循环；crossfade ~1200ms |
| `rain_bamboo_leaf` | `dw_official_amb_rain_bamboo_leaf_loop_sc_rain_soft_v02_t01.wav` | A03 竹叶雨 | 循环；音量低于近雨/远雨 |
| `wind_gust` | `dw_official_trg_wind_gust_oneshot_sc_rain_far_v03_t01.wav` | A04 阵风 oneshot | 非循环；timeline `play_oneshot` @ 188s / 458s |

历史：`wind_realistic` 曾用于 v6 两段循环起风；其它场景仍可引用，雨檐官方轨已改为 `wind_gust`。
