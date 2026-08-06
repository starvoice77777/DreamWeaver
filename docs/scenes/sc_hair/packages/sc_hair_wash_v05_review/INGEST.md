# sc_hair_wash_v05 review 包接入说明

本目录归档 2026-08 收到的 `0.5.0-review` 场景包元数据、时间线、文案、QC、授权与校验资料。原始包状态为 `review_ready_qc_pending`：可用于联调和演示，但 `release_ready=false`，不得据此标记为正式可发布素材。

为避免约 113 MB 音频在仓库内重复存储，`audio/master` 未在此目录重复归档。29 条母带按 `scene/tracks.csv` 的 `resource_key` 统一落在 `DreamWeaver/Resources/Audio/<resource_key>.wav`，并由 `server/scripts/build_hair_care_timeline_v11.py` 检查资源是否齐全、生成后端与 iOS 共用的 v11 fixture。

运行：

```powershell
server/.venv-codex/Scripts/python.exe server/scripts/build_hair_care_timeline_v11.py
```
