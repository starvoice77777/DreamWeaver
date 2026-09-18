# v1.2 单独音频入库（切片 1）

输入为 `backend_handoff_v1_2/audio_asset_index.csv` 中的 57 个 `source_library` 条目。
导入器校验全部 96 条索引的路径、大小和 SHA-256，原始交接包不修改、不提交。
本切片只建立 App 资源及索引；编辑器入口、场景时间线和后端 catalog 在后续切片接入。

## 处理与追溯

- 4 个文件与既有雨声/阵风母带哈希相同，复用原资源；其余 53 个编码为 48 kHz 双声道 AAC 160 kbps。
- 使用固定增益，目标 -24 LUFS、编码前峰值上限 -3.5 dBTP；编码后重新测量；AAC 峰值超过 -3 dBTP 时降低增益并从原文件重编码，最多三次，仍超限则拒绝导入。
- 保留原时长，不裁剪、不变速、不制作伪循环。后续播放需分别指定单次/循环模式和交叉淡化。
- `handoff_audio_catalog.json` 记录中文名、分类、原文件哈希、输出哈希、资源键及场景包资源键关联。
- 新增音频的实测响度写入 `audio_mastering_profile.json`，沿用现有播放增益逻辑。
- 索引中的 `assetStatus=qc_pending`、`licenseStatus=unreviewed` 是保守的入库状态，不代表场景授权结论。
  交接包原有的逐场景授权记录仍是后续审核依据，文件复用也不表示新用途已获授权。

## 开发试听范围

新增文件使用 `handoff_` 前缀，App target 的 Release 配置通过 `EXCLUDED_SOURCE_FILE_NAMES` 排除 `handoff_*`。
设置语义参见 [Apple Build settings reference](https://developer.apple.com/documentation/xcode/build-settings-reference)。
索引明确 `releaseReady=false`，后续素材选择入口必须仅在 Debug 加载。
口腔、刮擦、金属等敏感素材保留在索引中，不能因本次处理自动进入预设场景。
Windows 检查不替代 Xcode Release 产物检查、耳机/外放试听及循环接缝验收。

## 复现

在仓库根目录运行（使用已安装 `server[dev]` 的 Python，含 `imageio-ffmpeg`）：

```powershell
python scripts/import_handoff_audio.py <交接包绝对路径>
python -m pytest -c server/pyproject.toml server/tests/test_handoff_audio.py server/tests/test_scene_audio_assets.py
```

AAC 输出哈希可能随 FFmpeg 版本变化，更新后应重新审查索引与响度记录。
