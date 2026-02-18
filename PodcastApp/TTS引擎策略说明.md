# TTS引擎策略说明

## 概述

播客生成系统支持两种不同的TTS引擎策略，每种策略的工作流程和配置要求完全不同。

## 策略1：纯TTS引擎（需要LLM生成脚本）

### 工作流程
```
原文 → LLM生成对话脚本 → TTS合成音频
```

### 适用引擎
- **macOS系统TTS** (`TTSEngine.system`)
- **豆包语音合成2.0** (`TTSEngine.doubaoTTS`)
- **OpenAI TTS** (`TTSEngine.openai`)
- **ElevenLabs** (`TTSEngine.elevenlabs`)

### 配置要求
1. **必须配置LLM服务**
   - LLM Provider（如：豆包、OpenAI等）
   - LLM API Key
   - LLM Model

2. **必须配置TTS服务**
   - 根据选择的引擎配置对应的API Key和音色

### 代码实现
```swift
// 在 PodcastService.swift 中
private func generateWithTraditionalTTS(...) async throws -> Podcast {
    // 1. 验证LLM已配置
    guard let llmService = llmService else {
        throw PodcastError.llmNotConfigured
    }

    // 2. 使用LLM生成对话脚本
    let script = try await llmService.generatePodcastScript(...)

    // 3. 根据引擎选择正确的音色配置
    let voiceA: String
    let voiceB: String
    switch config.ttsEngine {
    case .doubaoTTS:
        voiceA = config.doubaoTTSVoiceA  // ✅ 正确
        voiceB = config.doubaoTTSVoiceB
    case .openai:
        voiceA = config.openaiTTSVoiceA
        voiceB = config.openaiTTSVoiceB
    case .system:
        voiceA = config.ttsVoiceA
        voiceB = config.ttsVoiceB
    // ...
    }

    // 4. 使用TTS合成音频
    let audioURL = try await ttsService.generateAudio(
        script: script,
        voiceA: voiceA,
        voiceB: voiceB,
        ...
    )
}
```

### 常见错误
❌ **错误1：使用错误的音色配置**
```swift
// 当引擎是 doubaoTTS 时，错误地使用了系统TTS的音色
let audioURL = try await ttsService.generateAudio(
    script: script,
    voiceA: config.ttsVoiceA,  // ❌ 错误！这是系统TTS的音色
    voiceB: config.ttsVoiceB,  // ❌ 错误！
    engine: .doubaoTTS
)
```

这会导致错误：`resource ID is mismatched with speaker related resource`

✅ **正确做法：根据引擎选择对应的音色配置**

---

## 策略2：一体化引擎（不需要LLM生成脚本）

### 工作流程
```
原文 → 一体化API（内部生成脚本+合成音频）
```

### 适用引擎
- **豆包播客API（一体化）** (`TTSEngine.doubaoPodcast`)

### 配置要求
1. **不需要配置LLM服务**
   - API内部自动完成脚本生成

2. **只需配置播客API**
   - App ID
   - Access Token
   - 音色配置（doubaoPodcastVoiceA/B）

### 代码实现
```swift
// 在 PodcastService.swift 中
private func generateWithDoubaoPodcast(...) async throws -> Podcast {
    // 1. 验证播客API配置
    guard !config.doubaoPodcastAppId.isEmpty &&
          !config.doubaoPodcastAccessToken.isEmpty else {
        throw PodcastError.generationFailed("豆包播客API配置不完整")
    }

    // 2. 准备输入文本（原文，不是对话脚本）
    let inputText = prepareInputText(from: articles, topics: topics, config: config)

    // 3. 直接调用一体化API
    try await doubaoPodcastService.generatePodcast(
        inputText: inputText,
        voiceA: config.doubaoPodcastVoiceA,  // ✅ 使用播客API的音色
        voiceB: config.doubaoPodcastVoiceB,
        outputURL: audioURL
    )
}
```

### 特点
- ✅ 配置简单，不需要单独配置LLM
- ✅ 一步到位，API内部完成所有处理
- ✅ 性能更好，减少了一次API调用

---

## 策略判断逻辑

### 在 TTSEngine 枚举中定义
```swift
enum TTSEngine: String, Codable {
    case system = "macOS系统TTS"
    case doubaoTTS = "豆包语音合成2.0"
    case openai = "OpenAI TTS"
    case elevenlabs = "ElevenLabs"
    case doubaoPodcast = "豆包播客API（一体化）"

    /// 是否需要LLM生成对话脚本
    var needsScriptGeneration: Bool {
        switch self {
        case .system, .doubaoTTS, .openai, .elevenlabs:
            return true  // 策略1：纯TTS引擎
        case .doubaoPodcast:
            return false // 策略2：一体化引擎
        }
    }
}
```

### 在 PodcastService 中使用
```swift
func generatePodcast(...) async throws -> Podcast {
    // 根据引擎策略选择生成方式
    if config.ttsEngine.needsScriptGeneration {
        // 策略1：纯TTS引擎 - 需要LLM生成脚本
        return try await generateWithTraditionalTTS(...)
    } else {
        // 策略2：一体化引擎 - 不需要LLM生成脚本
        switch config.ttsEngine {
        case .doubaoPodcast:
            return try await generateWithDoubaoPodcast(...)
        default:
            throw PodcastError.generationFailed("不支持的一体化引擎")
        }
    }
}
```

---

## 音色配置映射表

| TTS引擎 | 音色配置字段 | Resource ID字段 | 示例音色 |
|---------|-------------|----------------|----------|
| system | `ttsVoiceA/B` | - | `com.apple.voice.compact.zh-CN.Tingting` |
| doubaoTTS | `doubaoTTSVoiceA/B` | `doubaoTTSResourceId` | `zh_female_xiaohe_uranus_bigtts` |
| openai | `openaiTTSVoiceA/B` | - | `alloy`, `echo` |
| elevenlabs | `elevenlabsVoiceA/B` | - | 自定义音色ID |
| doubaoPodcast | `doubaoPodcastVoiceA/B` | - | `zh_female_shuangkuaisisi_moon_bigtts` |

---

## 添加新引擎的步骤

### 1. 确定引擎策略
- 是纯TTS引擎（需要LLM生成脚本）？
- 还是一体化引擎（不需要LLM）？

### 2. 更新 TTSEngine 枚举
```swift
enum TTSEngine: String, Codable {
    // ... 现有引擎
    case newEngine = "新引擎名称"

    var needsScriptGeneration: Bool {
        switch self {
        case .newEngine:
            return true  // 或 false，根据实际情况
        // ...
        }
    }
}
```

### 3. 添加配置字段到 UserConfig
```swift
struct UserConfig: Codable {
    // 新引擎配置
    var newEngineApiKey: String = ""
    var newEngineVoiceA: String = ""
    var newEngineVoiceB: String = ""
}
```

### 4. 更新 PodcastService
```swift
// 在 generateWithTraditionalTTS 中添加音色映射
switch config.ttsEngine {
case .newEngine:
    voiceA = config.newEngineVoiceA
    voiceB = config.newEngineVoiceB
    ttsApiKey = config.newEngineApiKey
// ...
}
```

### 5. 更新 TTSService
```swift
// 在 generateAudio 中添加引擎处理
switch engine {
case .newEngine:
    try await synthesizeWithNewEngine(...)
// ...
}
```

### 6. 更新设置页面
- 添加引擎选项
- 添加配置界面
- 添加音色选择器

---

## 测试检查清单

### 策略1：纯TTS引擎
- [ ] 未配置LLM时，是否正确提示错误？
- [ ] 是否使用了正确的音色配置字段？
- [ ] 音色ID与Resource ID是否匹配？
- [ ] 生成的脚本格式是否正确？

### 策略2：一体化引擎
- [ ] 是否跳过了LLM脚本生成步骤？
- [ ] 是否使用了正确的播客API配置？
- [ ] 输入文本格式是否符合API要求？
- [ ] 音频输出是否正常？

---

## 常见问题

### Q1: 为什么会出现"resource ID is mismatched with speaker related resource"错误？
**A:** 这是因为使用了错误的音色配置字段。例如：
- 选择了`doubaoTTS`引擎
- 但传递了`ttsVoiceA`（系统TTS的音色）
- 而不是`doubaoTTSVoiceA`（豆包TTS的音色）

### Q2: 如何判断一个引擎是否需要LLM？
**A:** 使用`TTSEngine.needsScriptGeneration`属性：
```swift
if config.ttsEngine.needsScriptGeneration {
    // 需要LLM
} else {
    // 不需要LLM
}
```

### Q3: 为什么一体化引擎不需要LLM？
**A:** 一体化引擎（如豆包播客API）内部已经集成了脚本生成功能，直接将原文发送给API，API会自动完成：
1. 内容分析
2. 对话脚本生成
3. 音频合成

这样可以减少API调用次数，提高性能。

---

## 总结

- **策略1（纯TTS）**：原文 → LLM → 脚本 → TTS → 音频
- **策略2（一体化）**：原文 → 一体化API → 音频

关键是要根据引擎类型选择正确的：
1. 生成流程（是否需要LLM）
2. 音色配置字段（每个引擎有自己的配置）
3. API调用方式（传递脚本 vs 传递原文）
