# AI 辅助场景音频素材交付与后端发送格式

> 适用范围：DreamWeaver AI 辅助生成 `/v1/ai/scene-assist/generate` 与辅助调整 `/v1/ai/scene-assist/adjust`。
>
> 契约基线：`origin/integration/frontend-backend` 提交 `59307f2`，核对日期 2026-09-18。

## 1. 结论

一段音频要进入 AI 辅助场景，需要完成两个不同步骤：

1. **上传二进制音频**：通过 `/v1/uploads` 创建上传会话，把文件 PUT 到对象存储，再调用 `/complete` 创建 `SoundAsset`。
2. **发送 AI 素材描述**：把上传后得到的资产 UUID 与声音描述、场景层级、循环和空间参数组装为 `selected_sources`，再调用 `/v1/ai/scene-assist/generate` 或 `/adjust`。

只有音频文件本身不够。AI 请求还必须有稳定的 `source_id` 和 `resource_key`，以及第 5 节列出的描述字段。

## 2. 交付给前后端团队的推荐目录

这不是新的后端接口，而是团队交接音频时推荐使用的文件包格式：

```text
audio-material-package/
├── manifest.json
├── files/
│   ├── rain_soft.wav
│   └── forest_birds.m4a
└── licenses/
    ├── rain_soft.txt
    └── forest_birds.txt
```

推荐的 `manifest.json`：

```json
{
  "package_version": "1.0",
  "materials": [
    {
      "filename": "rain_soft.wav",
      "name": "轻雨",
      "description": "柔和、连续、没有明显雷声的雨声",
      "kind": "environment",
      "layer": "environment",
      "resource_key": "rain_soft",
      "loop": true,
      "duration_seconds": 30,
      "default_volume": 0.3,
      "angle": 0,
      "radius": 0.8,
      "license_file": "licenses/rain_soft.txt",
      "source_id": null
    }
  ]
}
```

说明：

- `source_id` 在文件尚未上传时可以为 `null`；上传完成后必须替换成后端返回的资产 UUID。
- `license_file` 是团队交接和发布审核字段，当前上传 API 不接收它，但正式使用前仍必须保留授权凭证。
- `resource_key` 必须由前后端共同确认并保持稳定，不能每次运行随机生成。
- `kind` 和 `layer` 是两个不同概念：`kind` 表示资产类别，`layer` 表示它在场景中的声音层级。

## 3. 后端接受的文件格式

### 3.1 硬性限制

| 项目 | 后端要求 |
|---|---|
| 扩展名 | `m4a`、`mp3`、`wav`、`caf` |
| 最大文件大小 | 25 MiB，即 `26,214,400` 字节 |
| 文件大小 | 必须大于 0 |
| 上传鉴权 | `Authorization: Bearer <access_token>` |
| 上传会话有效期 | 默认 3600 秒 |
| 时长范围 | 0～86400 秒；用于 AI 时必须大于 0 |

允许的 MIME 类型：

| 文件 | 建议 MIME 类型 | 后端同时允许 |
|---|---|---|
| `.m4a` | `audio/mp4` | `audio/m4a`、`audio/x-m4a` |
| `.mp3` | `audio/mpeg` | `audio/mp3` |
| `.wav` | `audio/wav` | `audio/x-wav`、`audio/wave` |
| `.caf` | `audio/x-caf` | `audio/caf` |

后端当前分别校验扩展名和 MIME 类型是否位于允许列表中，但不会检查二者是否严格匹配。客户端仍应发送文件真实的 MIME 类型。

### 3.2 当前没有硬性规定的音频参数

当前上传接口没有校验以下内容：

- 采样率；
- 位深；
- 单声道或立体声；
- 编码码率；
- LUFS、峰值和动态范围；
- 是否可以无缝循环；
- 文件内是否包含静音、爆音或截幅。

这些参数不能因此视为“已通过”。正式使用前仍需执行资产 QC、许可证检查和 iOS 播放试听。

## 4. 上传 API 格式

### 4.1 创建上传会话

```http
POST /v1/uploads
Authorization: Bearer <access_token>
Content-Type: application/json
```

请求体：

```json
{
  "filename": "rain_soft.wav",
  "content_type": "audio/wav",
  "byte_size": 1234567,
  "kind": "environment",
  "name": "轻雨",
  "duration_seconds": 30
}
```

字段限制：

| 字段 | 必填 | 限制 |
|---|---:|---|
| `filename` | 是 | 1～256 字符，扩展名必须受支持 |
| `content_type` | 是 | 3～128 字符，值必须在允许的 MIME 列表中 |
| `byte_size` | 是 | 正整数，且不超过 25 MiB |
| `kind` | 否 | 默认 `life`；可选值见下表 |
| `name` | 否 | 最多 128 字符；省略时使用文件名主体 |
| `duration_seconds` | 否 | 整数，0～86400；默认 0 |

后端 `kind` 可选值：

| 值 | 含义 |
|---|---|
| `life` | 用户日常录音或普通个人素材 |
| `voice` | 人声素材 |
| `environment` | 环境声素材 |
| `official` | 官方类别标记 |

注意：普通上传接口创建的资产始终属于当前登录用户。仅把 `kind` 写成 `official`，不会自动把它变成所有用户可见的全局官方目录素材。

成功响应：

```json
{
  "upload_id": "11111111-1111-4111-8111-111111111111",
  "put_url": "https://object-storage.example/...",
  "storage_key": "uploads/<user-id>/<upload-id>/source.wav",
  "required_headers": {
    "Content-Type": "audio/wav"
  },
  "expires_at": "2026-09-18T12:00:00Z",
  "max_byte_size": 26214400
}
```

### 4.2 PUT 原始音频

客户端向响应中的 `put_url` 发送原始二进制文件，并原样携带 `required_headers`：

```http
PUT <put_url>
Content-Type: audio/wav

<raw audio bytes>
```

这里发送的是音频二进制，不是 Base64，也不是 JSON 或 multipart 表单。

### 4.3 完成上传并创建资产

```http
POST /v1/uploads/{upload_id}/complete?duration_seconds=30
Authorization: Bearer <access_token>
```

成功后返回：

```json
{
  "id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
  "name": "轻雨",
  "kind": "environment",
  "symbol_name": "waveform",
  "duration_seconds": 30,
  "content_type": "audio/wav",
  "byte_size": 1234567,
  "is_favorite": false,
  "processing_status": "ready",
  "created_at": "2026-09-18T11:00:00Z",
  "updated_at": "2026-09-18T11:00:00Z"
}
```

返回值中的 `id` 就是 AI 请求所需的 `source_id`。

当前实现中，最终资产时长取 `/complete` 查询参数中的 `duration_seconds`。为保持兼容，创建上传会话和完成上传时应传入相同的时长。

### 4.4 完成上传时的校验

- 上传对象必须存在且不能为空。
- 实际大小不能超过 25 MiB。
- 实际大小不能明显大于声明的 `byte_size`；当前容差为 `声明值 × 1.05 + 1024` 字节。
- 上传会话过期后返回 410。
- 同一个已完成的 `upload_id` 再次调用 `/complete` 会返回已创建的资产。

## 5. AI 接口的 `selected_sources` 格式

AI 接口不接收音频二进制。它接收已经注册完成的资产描述数组：

```json
{
  "selected_sources": [
    {
      "source_id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
      "resource_key": "rain_soft",
      "name": "轻雨",
      "description": "柔和、连续、没有明显雷声的雨声",
      "layer": "environment",
      "loop": true,
      "duration_seconds": 30,
      "default_volume": 0.3,
      "angle": 0,
      "radius": 0.8
    }
  ],
  "options": {
    "scene_intent": "睡前放松",
    "duration_seconds": 1800,
    "language": "zh-CN",
    "constraints": ["不要加入人声"]
  }
}
```

### 5.1 素材字段限制

| 字段 | 类型 | 后端限制 |
|---|---|---|
| `source_id` | UUID | 必填；使用上传完成响应中的 `id` |
| `resource_key` | String | 必填；1～128 字符，只允许小写字母、数字和下划线，正则 `^[a-z0-9_]+$` |
| `name` | String | 必填；1～128 字符 |
| `description` | String | 必填；1～2000 字符 |
| `layer` | String | 必填；`environment`、`ambience`、`trigger`、`voice` 之一 |
| `loop` | Boolean | 必填；是否允许循环播放 |
| `duration_seconds` | Number | 必填；大于 0 且不超过 86400 |
| `default_volume` | Number | 必填；0～1 |
| `angle` | Number | 必填；弧度，范围 `-π`～`π` |
| `radius` | Number | 必填；0～1，0 为中心，1 为圆盘边缘 |

`selected_sources` 必须包含 1～64 项。请求模型禁止未声明的额外字段。

### 5.2 `layer` 的使用建议

| 值 | 用途 |
|---|---|
| `environment` | 主要环境底声，例如雨、风、海浪 |
| `ambience` | 辅助氛围或音乐铺底 |
| `trigger` | 短促事件、物件声或偶发细节 |
| `voice` | 旁白、提示语或其他人声 |

### 5.3 `resource_key` 当前缺口

`POST /v1/uploads/{id}/complete` 返回的 `SoundAsset` 没有 `resource_key` 字段，但 AI 的 `SelectedSourceIn` 又要求该字段必填。因此在正式接线前，必须由前后端共同确定以下方案之一：

1. 后端为每个上传资产生成并返回稳定的 `resource_key`；或
2. 前端按双方约定生成稳定 key，并由后端认可和持久化；或
3. AI 契约允许仅靠 `source_id` 识别上传资产，并把 `resource_key` 改为可选。

在方案确认前，不要使用随机 UUID、中文、空格或包含连字符的前端临时 ID 代替 `resource_key`。

## 6. 生成与调整请求

### 6.1 AI 一键生成

```http
POST /v1/ai/scene-assist/generate
Authorization: Bearer <access_token>
Content-Type: application/json
```

请求体使用第 5 节格式。后端依次完成 outline、arrangement 和 compile，返回 `scene_composition_v2` 草稿。

### 6.2 AI 辅助调整

```http
POST /v1/ai/scene-assist/adjust
Authorization: Bearer <access_token>
Content-Type: application/json
```

除 `selected_sources` 外，还必须携带当前场景和自然语言指令：

```json
{
  "selected_sources": [],
  "scene": {
    "name": "檐下听雨",
    "composition": {
      "schema": "scene_composition_v2",
      "version": 2,
      "duration_seconds": 1800,
      "source_groups": [],
      "clips": []
    }
  },
  "instruction": "把雨声降低一些，保持所有声源不变",
  "options": {
    "duration_seconds": 1800,
    "language": "zh-CN"
  }
}
```

上例中的空数组只用于展示外层结构；真实请求的 `selected_sources`、`source_groups` 和 `clips` 都必须包含当前场景对应的数据。

## 7. 当前接口没有保存的素材元数据

上传完成返回的 `SoundAsset` 目前不包含以下 AI 必需或发布审核需要的信息：

- `resource_key`；
- `description`；
- `layer`；
- `loop`；
- `default_volume`；
- 初始 `angle` 和 `radius`；
- 许可证与来源凭证；
- 无缝循环、响度和其他 QC 结果。

在后端增加素材元数据表或相应字段之前，这些信息必须保存在受控的目录清单或前端映射中。不能只依赖音频文件名临时推断。

## 8. 交付前检查清单

每段音频至少应确认：

- [ ] 扩展名属于 `m4a/mp3/wav/caf`。
- [ ] 文件不为空且不超过 25 MiB。
- [ ] 文件可以正常解码和播放。
- [ ] `filename`、`content_type`、`byte_size` 与实际文件一致。
- [ ] 名称和描述可以让 AI 理解声音用途。
- [ ] `kind` 与 `layer` 已分别填写。
- [ ] `resource_key` 为稳定的小写字母、数字和下划线组合。
- [ ] 时长已测量；AI 使用值必须大于 0。
- [ ] 已确认是否允许循环；需要循环的素材已经人工试听接缝。
- [ ] 默认音量在 0～1 范围内并经过试听。
- [ ] 初始角度使用弧度，半径在 0～1 范围内。
- [ ] 授权来源和可使用范围有书面记录。
- [ ] 上传完成后已记录后端返回的 `source_id`。
- [ ] iOS 端能够通过资产 ID 获取播放 URL 并试听。

## 9. 当前阻塞项

正式把 DreamWeaver 辅助画布接到 AI 后端前，还需确认：

1. 静态推荐素材与真实后端资产 UUID 的对应关系。
2. 上传资产 `resource_key` 的生成与持久化规则。
3. `environment` 类型在 iOS 素材列表中的展示映射。
4. 官方共享素材是否走独立 catalog，而不是用户私有上传接口。
5. 部署环境是否已配置 `DW_DEEPSEEK_API_KEY`。

## 10. 安全与发布边界

- 不要把 DeepSeek 密钥放进音频包、iOS 工程、请求日志或 Git。
- AI 返回内容只能作为草稿预览，不能自动发布。
- AI schema 校验通过不等于音频素材已经通过质量或授权审核。
- 保存正式版本前必须完成人工试听、资产 QC 和许可证检查。

## 11. 代码依据

- 文件扩展名、MIME、kind 与上传 DTO：`server/app/schemas/library.py`
- 上传大小、过期和对象校验：`server/app/services/library.py`
- 上传 API：`server/app/api/v1/library.py`
- 默认上传限制：`server/app/core/config.py`
- AI 素材字段和范围：`server/app/schemas/ai_scene.py`
- AI 前端交接说明：`docs/ai-scene-assist-api.md`
