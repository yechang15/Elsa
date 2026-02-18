# TTS引擎策略重构总结

## 问题背景

在生成播客时出现错误：`resource ID is mismatched with speaker related resource`

根本原因：
1. 选择了"豆包语音合成2.0"引擎
2. 但代码传递了错误的音色配置（系统TTS的音色而不是豆包TTS的音色）
3. 系统TTS的音色ID（如`com.apple.voice.compact.zh-CN.Tingting`）与火山引擎的resource ID完全不匹配

## 核心问题

系统没有明确区分两种不同的TTS引擎策略：
- **策略1：纯TTS引擎** - 需要LLM先生成对话脚本，再用TTS合成音频
- **策略2：一体化引擎** - 直接将原文发送给API，由API内部完成脚本生成和音频合成

这导致：
- 音色配置传递错误
- 工作流程混乱
- 容易在添加新引擎时犯同样的错误

## 解决方案

### 1. 在TTSEngine枚举中明确定义策略

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

    /// 工作流程描述
    var workflow: String {
        switch self {
        case .system, .doubaoTTS, .openai, .elevenlabs:
            return "原文 → LLM生成对话脚本 → TTS合成音频"
        case .doubaoPodcast:
            return "原文 → 一体化API（内部生成脚本+合成音频）"
        }
    }
}
```

### 2. 在PodcastService中使用策略属性

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

### 3. 修复音色配置传递

```swift
// 根据 TTS 引擎选择正确的音色配置
let voiceA: String
let voiceB: String

switch config.ttsEngine {
case .doubaoTTS:
    voiceA = config.doubaoTTSVoiceA  // ✅ 正确
    voiceB = config.doubaoTTSVoiceB
case .openai:
    voiceA = config.openaiTTSVoiceA
    voiceB = config.openaiTTSVoiceB
case .elevenlabs:
    voiceA = config.elevenlabsVoiceA
    voiceB = config.elevenlabsVoiceB
default:
    voiceA = config.ttsVoiceA
    voiceB = config.ttsVoiceB
}
```

### 4. 添加音色验证

在`VolcengineBidirectionalTTS.synthesize`方法中添加验证：

```swift
func synthesize(text: String, voice: String, speed: Float = 1.0) async throws -> Data {
    // 验证音色是否与resource ID匹配
    let availableVoices = VolcengineVoices.voices(for: resourceId)
    guard availableVoices.contains(where: { $0.id == voice }) else {
        throw TTSError.invalidVoice("音色 '\(voice)' 不支持 Resource ID '\(resourceId)'")
    }
    // ...
}
```

### 5. 更新设置页面UI

使用`TTSEngine.needsScriptGeneration`属性动态显示引擎说明：

```swift
VStack(alignment: .leading, spacing: 4) {
    Text(localTTSEngine.needsScriptGeneration ? "📱 纯TTS引擎" : "🎙️ 一体化引擎")
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundColor(localTTSEngine.needsScriptGeneration ? .blue : .green)

    Text("• \(localTTSEngine.workflow)")
        .font(.caption)
        .foregroundColor(.secondary)

    if localTTSEngine.needsScriptGeneration {
        Text("• ⚠️ 需要配合上方的 LLM 先生成对话脚本")
            .font(.caption)
            .foregroundColor(.orange)
    } else {
        Text("• ✅ 不需要单独配置 LLM，一步到位")
            .font(.caption)
            .foregroundColor(.green)
    }
}
```

## 修改的文件

1. **TTSService.swift**
   - 添加`TTSEngine.needsScriptGeneration`属性
   - 添加`TTSEngine.workflow`属性
   - 添加`TTSError.invalidVoice`错误类型

2. **VolcengineBidirectionalTTS.swift**
   - 添加音色验证逻辑

3. **PodcastService.swift**
   - 使用`needsScriptGeneration`属性判断策略
   - 修复音色配置传递逻辑
   - 添加详细的注释说明

4. **SettingsView.swift**
   - 使用引擎属性动态显示说明
   - 统一UI展示逻辑

5. **文档**
   - 创建`TTS引擎策略说明.md`详细文档
   - 创建`test_tts_strategy.swift`测试脚本

## 效果

### 修复前
```
❌ 选择"豆包语音合成2.0"引擎
❌ 传递系统TTS音色 → 音色ID不匹配 → 报错
```

### 修复后
```
✅ 选择"豆包语音合成2.0"引擎
✅ 自动传递豆包TTS音色 → 音色ID匹配 → 成功
✅ 音色验证 → 提前发现配置错误
```

## 未来扩展

添加新引擎时，只需：

1. 在`TTSEngine`枚举中添加新case
2. 在`needsScriptGeneration`中指定策略
3. 添加对应的配置字段
4. 在音色映射中添加处理逻辑

系统会自动：
- 选择正确的生成流程
- 显示正确的UI说明
- 验证配置完整性

## 测试验证

运行`swift test_tts_strategy.swift`验证策略正确性：

```
✅ 策略1 - 纯TTS引擎（需要LLM）:
  • macOS系统TTS
  • 豆包语音合成2.0
  • OpenAI TTS
  • ElevenLabs

✅ 策略2 - 一体化引擎（不需要LLM）:
  • 豆包播客API（一体化）
```

## 总结

通过明确定义TTS引擎策略，我们：
1. ✅ 修复了音色配置传递错误
2. ✅ 使代码逻辑更清晰
3. ✅ 防止未来犯同样的错误
4. ✅ 简化了新引擎的添加流程
5. ✅ 提供了完整的文档和测试
