# sc_hair_wash_v05｜洗头陪伴场景审核包

- 场景名称：洗头陪伴
- 场景类型：过程型（20 句短提示 + 环境/动作声）
- 目标时长：10 分 20 秒
- 输出策略：手机外放与耳机兼容
- 当前状态：`review_ready_qc_pending`
- 正式上架：`release_ready=false`
- 真相源：`scene/timeline.json`
- 适用规范：`scene-creation-spec-v1.1-rev3`

## 本版变化

20 条人声已替换为 `8月5日 (1).wav` 的原声直切 v02：保持 48 kHz PCM16 双声道和原采样值；不降噪、不均衡、不压缩、不限幅、不归一化、不补静音、不加淡入淡出。第 20 句起点提前至 10:04，确保在 10:12 最终淡出前完成并留出 300ms 恢复窗口。

## 提交状态

目录与引用已按标准场景包模板整理，可供产品、后端、素材与测试联合审阅。由于当前 20 条人声响度和多数时长不满足正式人声母带建议值，且声线授权、非人声许可证、实机试听、loop 连续试听和路径安全校验尚未完成，本包不得进入正式 Bundle。

## 校验

```powershell
python tools/validate_scene_package.py . --ffprobe <ffprobe.exe> --out qc/reports/package_validation.json
```
