# 火山引擎双向流式TTS集成说明

## 概述

已成功将火山引擎的双向流式TTS API集成到PodcastApp中，作为纯TTS引擎使用。

## 集成内容

### 1. 新增文件
- `PodcastApp/Services/TTS/VolcengineBidirectionalTTS.swift` - 火山引擎双向流式TTS服务类

### 2. 修改文件
- `AppState.swift` - 添加火山引擎TTS配置项
- `TTSService.swift` - 集成火山引擎TTS合成方法
- `SettingsView.swift` - 添加火山引擎TTS配置界面
- `PodcastService.swift` - 更新TTS调用参数

## 配置说明

### 必需参数
1. **App ID** - 火山引擎控制台获取的APP ID
2. **Access Token** - 火山引擎控制台获取的Access Token
3. **Resource ID** - 选择使用的模型：
   - `seed-tts-1.0` - 豆包语音合成1.0
   - `seed-tts-1.0-concurr` - 豆包语音合成1.0（并发版）
   - `seed-tts-2.0` - 豆包语音合成2.0（推荐）
   - `seed-icl-1.0` - 声音复刻1.0
   - `seed-icl-1.0-concurr` - 声音复刻1.0（并发版）
   - `seed-icl-2.0` - 声音复刻2.0

### 音色配置
- **主播A语音ID** - 例如：`zh_female_tianmeixiaoyuan`
- **主播B语音ID** - 例如：`zh_male_aojiaobazong`

音色列表参考：https://www.volcengine.com/docs/6561/1257544

## 使用流程

1. 在设置页面选择"豆包语音合成2.0"作为TTS引擎
2. 填写App ID和Access Token
3. 选择Resource ID（推荐使用seed-tts-2.0）
4. 配置主播A和主播B的音色ID
5. 在生成播客时，系统会：
   - 使用LLM生成播客脚本
   - 使用火山引擎TTS将脚本转换为音频

## 技术实现

### WebSocket通信
- 使用URLSession的WebSocketTask实现双向通信
- 支持连接复用，可在同一连接下进行多次会话

### 消息格式
- 二进制帧格式：Header（4字节）+ Payload（JSON）
- Header结构：协议版本(1字节) + 消息类型(1字节) + Flags(2字节)

### 主要消息类型
- StartConnection (0x0b) - 建立连接
- StartSession (0x97) - 开始会话
- TaskRequest (0x99) - 发送文本
- AudioData (0x9b) - 接收音频数据
- FinishSession (0x9d) - 结束会话
- FinishConnection (0x0f) - 断开连接

### 音频处理
- 接收的音频数据为Base64编码的MP3格式
- 自动解码并保存为临时文件
- 多段对话音频自动合并为完整播客

## 注意事项

1. **纯TTS引擎** - 这不是一体化方案，需要配合LLM使用
2. **连接管理** - 每次合成都会建立新连接，适合批量处理
3. **错误处理** - 包含完整的错误处理和重试机制
4. **音频格式** - 输出为MP3格式，采样率24000Hz

## 与其他TTS引擎的区别

| 引擎 | 类型 | 特点 |
|------|------|------|
| macOS系统TTS | 纯TTS | 免费，无需配置，音质一般 |
| 火山引擎双向流式TTS | 纯TTS | 高质量，支持多种音色，需要配置 |
| OpenAI TTS | 纯TTS | 高质量，英文效果好（未实现） |
| ElevenLabs | 纯TTS | 超自然音质（未实现） |
| 豆包播客API | 一体化 | 脚本生成+音频合成一步完成 |

## 获取凭证

访问火山引擎控制台：https://console.volcengine.com/speech/service
1. 创建应用获取App ID
2. 生成Access Token
3. 选择合适的Resource ID
