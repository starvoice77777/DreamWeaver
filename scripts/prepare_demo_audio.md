# 演示音频准备说明

当前已将候选素材复制到 `DreamWeaver/Resources/Audio/`。

## 推荐转码（在 macOS 上执行）

```bash
# 需要 brew install ffmpeg
cd DreamWeaver/Resources/Audio
for f in *.wav; do
  ffmpeg -y -i "$f" -ac 2 -ar 48000 -c:a aac -b:a 128k "${f%.wav}.m4a"
done
```

转码后：

1. 更新 JSON / `DemoCatalog` 中的 `resourceName` 为 `.m4a`
2. 从 Bundle 移除超大 `.wav` 以控制安装包体积
3. 保留原始文件于仓库外的 `音料库/` 作为母带

## 人声短句

将授权后的短句导出为：

- 文件名：`voice_phrase_mom.m4a`
- 建议时长：8–20 秒
- 内容示例：「把头低一下，我给你擦头发。」

覆盖 `Resources/Audio/voice_phrase_mom.m4a`（当前为静音占位）。
