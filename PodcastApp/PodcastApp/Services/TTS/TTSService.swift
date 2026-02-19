import Foundation
import AVFoundation
#if os(macOS)
import AppKit
#endif

/// TTS语音合成服务
class TTSService: NSObject, ObservableObject {
    private nonisolated(unsafe) let synthesizer = AVSpeechSynthesizer()
    @Published var isSpeaking = false

    #if os(macOS)
    // 复用 NSSpeechSynthesizer 实例，避免频繁创建销毁
    private var nsSpeechSynthesizer: NSSpeechSynthesizer?
    private let synthesizerLock = NSLock()
    #endif

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// 将播客脚本转换为音频文件
    /// 返回: (音频文件URL, 脚本段落时间戳数组)
    func generateAudio(script: String, voiceA: String, voiceB: String, speed: Float = 1.0, engine: TTSEngine = .system, apiKey: String = "", appId: String = "", accessToken: String = "", resourceId: String = "seed-tts-2.0") async throws -> (URL, [ScriptSegment]) {
        // 解析脚本
        let dialogues = parseScript(script)

        // 创建临时音频文件
        let tempDir = FileManager.default.temporaryDirectory
        let audioFileName = "podcast_\(UUID().uuidString).m4a"
        let audioURL = tempDir.appendingPathComponent(audioFileName)

        // 根据引擎选择合成方式
        switch engine {
        case .system:
            return try await synthesizeToFile(dialogues: dialogues, voiceA: voiceA, voiceB: voiceB, speed: speed, outputURL: audioURL)
        case .doubaoTTS:
            return try await synthesizeWithVolcengineBidirectionalTTS(dialogues: dialogues, voiceA: voiceA, voiceB: voiceB, speed: speed, appId: appId, accessToken: accessToken, resourceId: resourceId, outputURL: audioURL)
        default:
            throw TTSError.unsupportedEngine
        }
    }

    /// 解析播客脚本
    /// 支持格式：
    /// - "主播A：内容" 或 "主播A:内容"
    /// - "主播B：内容" 或 "主播B:内容"
    /// - "小何：内容" 或 "小何:内容"（自定义主播名）
    /// - "云舟：内容" 或 "云舟:内容"（自定义主播名）
    private func parseScript(_ script: String) -> [Dialogue] {
        let lines = script.components(separatedBy: .newlines)
        var dialogues: [Dialogue] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            // 尝试匹配 "名称：内容" 或 "名称:内容" 格式
            if let colonIndex = trimmed.firstIndex(where: { $0 == "：" || $0 == ":" }) {
                let speakerName = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let content = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

                // 判断是主播A还是主播B
                // 规则：包含"A"、奇数位置、或者是第一个出现的名称 -> 主播A
                //      包含"B"、偶数位置、或者是第二个出现的名称 -> 主播B
                let speaker: Dialogue.Speaker
                if speakerName.contains("A") || speakerName == "主播A" {
                    speaker = .hostA
                } else if speakerName.contains("B") || speakerName == "主播B" {
                    speaker = .hostB
                } else {
                    // 根据对话顺序交替分配
                    speaker = dialogues.isEmpty || dialogues.last?.speaker == .hostB ? .hostA : .hostB
                }

                dialogues.append(Dialogue(speaker: speaker, content: content))
            }
        }

        return dialogues
    }

    /// 使用火山引擎双向流式TTS合成音频
    private func synthesizeWithVolcengineBidirectionalTTS(dialogues: [Dialogue], voiceA: String, voiceB: String, speed: Float, appId: String, accessToken: String, resourceId: String, outputURL: URL) async throws -> (URL, [ScriptSegment]) {
        print("=== 使用火山引擎双向流式TTS合成音频 ===")
        print("对话数量: \(dialogues.count)")
        print("输出路径: \(outputURL.path)")

        var audioFiles: [URL] = []

        // 为每段对话生成音频
        for (index, dialogue) in dialogues.enumerated() {
            print("合成第 \(index + 1)/\(dialogues.count) 段对话...")

            let voice = dialogue.speaker == .hostA ? voiceA : voiceB

            // 创建TTS服务实例
            let ttsService = VolcengineBidirectionalTTS(
                appId: appId,
                accessToken: accessToken,
                resourceId: resourceId
            )

            // 合成音频
            let audioData = try await ttsService.synthesize(
                text: dialogue.content,
                voice: voice,
                speed: speed
            )

            print("   收到音频数据: \(audioData.count) 字节")

            // 验证音频数据不为空
            guard audioData.count > 0 else {
                print("❌ 音频数据为空，跳过此段对话")
                continue
            }

            // 保存音频数据到临时文件
            let tempFile = FileManager.default.temporaryDirectory
                .appendingPathComponent("dialogue_\(index)_\(UUID().uuidString).mp3")
            try audioData.write(to: tempFile)

            // 验证文件写入成功
            if let attrs = try? FileManager.default.attributesOfItem(atPath: tempFile.path),
               let fileSize = attrs[.size] as? Int64 {
                print("   临时文件已保存: \(tempFile.lastPathComponent) (\(fileSize) 字节)")
            }

            // 验证音频文件是否有效
            let asset = AVURLAsset(url: tempFile)
            do {
                let tracks = try await asset.loadTracks(withMediaType: .audio)
                if tracks.isEmpty {
                    print("⚠️ 警告：音频文件无效，没有音频轨道")
                    try? FileManager.default.removeItem(at: tempFile)
                    continue
                }
                let duration = try await asset.load(.duration)
                print("   音频验证成功，时长: \(CMTimeGetSeconds(duration)) 秒")
            } catch {
                print("❌ 音频文件验证失败: \(error.localizedDescription)")
                try? FileManager.default.removeItem(at: tempFile)
                continue
            }

            audioFiles.append(tempFile)

            print("✅ 第 \(index + 1) 段对话合成完成")
        }

        guard !audioFiles.isEmpty else {
            throw TTSError.audioProcessingFailed
        }

        // 合并所有音频文件
        print("合并音频文件...")
        let segments = try await mergeAudioFiles(audioFiles, dialogues: dialogues, outputURL: outputURL)

        // 清理临时文件
        for file in audioFiles {
            try? FileManager.default.removeItem(at: file)
        }

        print("✅ 音频合成完成: \(outputURL.path)")
        return (outputURL, segments)
    }

    /// 使用豆包 TTS API 合成音频（已废弃，保留用于兼容）
    private func synthesizeWithDoubaoTTS(dialogues: [Dialogue], voiceA: String, voiceB: String, speed: Float, apiKey: String, outputURL: URL) async throws -> (URL, [ScriptSegment]) {
        print("=== 使用豆包 TTS API 合成音频 ===")
        print("对话数量: \(dialogues.count)")
        print("输出路径: \(outputURL.path)")

        var audioFiles: [URL] = []

        // 为每段对话生成音频
        for (index, dialogue) in dialogues.enumerated() {
            print("合成第 \(index + 1)/\(dialogues.count) 段对话...")

            let voice = dialogue.speaker == .hostA ? voiceA : voiceB
            let audioData = try await callDoubaoTTSAPI(
                text: dialogue.content,
                voice: voice,
                speed: speed,
                apiKey: apiKey
            )

            // 保存音频数据到临时文件
            let tempFile = FileManager.default.temporaryDirectory
                .appendingPathComponent("dialogue_\(index)_\(UUID().uuidString).mp3")
            try audioData.write(to: tempFile)
            audioFiles.append(tempFile)
        }

        print("合并音频文件...")
        // 合并所有音频文件
        let segments = try await mergeAudioFiles(audioFiles, dialogues: dialogues, outputURL: outputURL)

        // 清理临时文件
        for file in audioFiles {
            try? FileManager.default.removeItem(at: file)
        }

        print("✅ 音频合成完成")
        return (outputURL, segments)
    }

    /// 调用豆包 TTS API
    private func callDoubaoTTSAPI(text: String, voice: String, speed: Float, apiKey: String) async throws -> Data {
        let url = URL(string: "https://openspeech.bytedance.com/api/v1/tts")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // 构建请求体
        let requestBody: [String: Any] = [
            "app": [
                "appid": "your_app_id", // 需要配置
                "token": apiKey,
                "cluster": "volcano_tts"
            ],
            "user": [
                "uid": "user_\(UUID().uuidString)"
            ],
            "audio": [
                "voice_type": voice,
                "encoding": "mp3",
                "speed_ratio": speed,
                "volume_ratio": 1.0,
                "pitch_ratio": 1.0
            ],
            "request": [
                "reqid": UUID().uuidString,
                "text": text,
                "text_type": "plain",
                "operation": "query"
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            if let errorString = String(data: data, encoding: .utf8) {
                print("豆包 TTS API 错误 (状态码: \(statusCode)): \(errorString)")
            }
            throw TTSError.apiError("豆包 TTS API 请求失败，状态码: \(statusCode)")
        }

        // 解析响应
        let result = try JSONDecoder().decode(DoubaoTTSResponse.self, from: data)

        guard let audioBase64 = result.data else {
            throw TTSError.apiError("豆包 TTS API 返回数据为空")
        }

        // Base64 解码音频数据
        guard let audioData = Data(base64Encoded: audioBase64) else {
            throw TTSError.apiError("音频数据解码失败")
        }

        return audioData
    }
    private func synthesizeToFile(dialogues: [Dialogue], voiceA: String, voiceB: String, speed: Float, outputURL: URL) async throws -> (URL, [ScriptSegment]) {
        print("=== 开始合成音频 ===")
        print("对话数量: \(dialogues.count)")
        print("输出路径: \(outputURL.path)")

        // 创建音频文件数组
        var audioFiles: [URL] = []

        // 为每段对话生成音频
        for (index, dialogue) in dialogues.enumerated() {
            print("合成第 \(index + 1)/\(dialogues.count) 段对话...")

            let voice = dialogue.speaker == .hostA ? voiceA : voiceB
            let tempFile = FileManager.default.temporaryDirectory
                .appendingPathComponent("dialogue_\(index)_\(UUID().uuidString).caf")

            try await synthesizeSingleDialogue(
                text: dialogue.content,
                voice: voice,
                speed: speed,
                outputURL: tempFile
            )

            audioFiles.append(tempFile)
        }

        print("合并音频文件...")
        // 合并所有音频文件
        let segments = try await mergeAudioFiles(audioFiles, dialogues: dialogues, outputURL: outputURL)

        // 清理临时文件
        for file in audioFiles {
            try? FileManager.default.removeItem(at: file)
        }

        print("✅ 音频合成完成")
        return (outputURL, segments)
    }

    /// 合成单段对话
    private func synthesizeSingleDialogue(text: String, voice: String, speed: Float, outputURL: URL) async throws {
        #if os(macOS)
        // macOS: 使用 NSSpeechSynthesizer（虽然已弃用，但是最可靠的方法）
        try await synthesizeWithNSSpeech(text: text, voice: voice, speed: speed, outputURL: outputURL)
        #elseif os(iOS)
        // iOS: 使用 AVSpeechSynthesizer（暂不支持写入文件，需要实时播放）
        throw TTSError.unsupportedPlatform
        #else
        throw TTSError.unsupportedPlatform
        #endif
    }

    #if os(macOS)
    /// macOS: 使用 NSSpeechSynthesizer 合成音频到文件
    /// 注意：NSSpeechSynthesizer 在 macOS 14.0 中已被弃用，但仍然可用
    private func synthesizeWithNSSpeech(text: String, voice: String, speed: Float, outputURL: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            synthesizerLock.lock()

            // 复用或创建 synthesizer
            if nsSpeechSynthesizer == nil {
                nsSpeechSynthesizer = NSSpeechSynthesizer()
            }

            guard let speechSynthesizer = nsSpeechSynthesizer else {
                synthesizerLock.unlock()
                continuation.resume(throwing: TTSError.audioProcessingFailed)
                return
            }

            // 设置音色
            let nsVoice = NSSpeechSynthesizer.VoiceName(rawValue: voice)
            speechSynthesizer.setVoice(nsVoice)

            // 设置语速 (NSSpeechSynthesizer 的速度范围通常是 90-720，默认约 200)
            let baseRate: Float = 200.0
            speechSynthesizer.rate = baseRate * speed

            // 开始合成到文件
            let success = speechSynthesizer.startSpeaking(text, to: outputURL)

            synthesizerLock.unlock()

            if success {
                // 等待合成完成
                DispatchQueue.global().async {
                    while speechSynthesizer.isSpeaking {
                        Thread.sleep(forTimeInterval: 0.1)
                    }

                    // 验证文件是否生成
                    if FileManager.default.fileExists(atPath: outputURL.path) {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: TTSError.audioProcessingFailed)
                    }
                }
            } else {
                continuation.resume(throwing: TTSError.audioProcessingFailed)
            }
        }
    }
    #endif

    /// 合并音频文件
    private func mergeAudioFiles(_ files: [URL], dialogues: [Dialogue], outputURL: URL) async throws -> [ScriptSegment] {
        print("=== 开始合并音频文件 ===")
        print("文件数量: \(files.count)")

        let composition = AVMutableComposition()

        guard let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw TTSError.audioProcessingFailed
        }

        var currentTime = CMTime.zero
        var successCount = 0
        var segments: [ScriptSegment] = [] // 记录时间戳

        for (index, fileURL) in files.enumerated() {
            print("处理文件 \(index + 1)/\(files.count): \(fileURL.lastPathComponent)")

            // 检查文件是否存在
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                print("⚠️ 文件不存在: \(fileURL.path)")
                continue
            }

            // 检查文件大小
            if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let fileSize = attrs[.size] as? Int64 {
                print("   文件大小: \(fileSize) 字节")
                if fileSize == 0 {
                    print("⚠️ 文件为空，跳过")
                    continue
                }
            }

            let asset = AVURLAsset(url: fileURL)

            // 尝试加载音频轨道
            do {
                let tracks = try await asset.loadTracks(withMediaType: .audio)
                guard let assetTrack = tracks.first else {
                    print("⚠️ 无法加载音频轨道，跳过")
                    continue
                }

                let duration = try await asset.load(.duration)
                print("   音频时长: \(CMTimeGetSeconds(duration)) 秒")

                let timeRange = CMTimeRange(start: .zero, duration: duration)
                try audioTrack.insertTimeRange(timeRange, of: assetTrack, at: currentTime)

                // 记录时间戳
                let startTime = CMTimeGetSeconds(currentTime)
                let endTime = startTime + CMTimeGetSeconds(duration)

                // 获取对应的对话内容
                if index < dialogues.count {
                    let dialogue = dialogues[index]
                    let speakerName = dialogue.speaker == .hostA ? "主播A" : "主播B"
                    let segment = ScriptSegment(
                        speaker: speakerName,
                        content: dialogue.content,
                        startTime: startTime,
                        endTime: endTime
                    )
                    segments.append(segment)
                    print("   记录段落: \(speakerName) [\(String(format: "%.2f", startTime))s - \(String(format: "%.2f", endTime))s]")
                }

                currentTime = CMTimeAdd(currentTime, duration)
                successCount += 1
                print("✅ 文件添加成功")
            } catch {
                print("❌ 处理文件失败: \(error.localizedDescription)")
                continue
            }
        }

        guard successCount > 0 else {
            throw TTSError.audioProcessingFailed
        }

        print("成功添加 \(successCount) 个音频文件到合成轨道")

        // 导出合并后的音频
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            print("❌ 无法创建导出会话")
            throw TTSError.audioProcessingFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        print("开始导出到: \(outputURL.path)")
        await exportSession.export()

        if exportSession.status != .completed {
            let errorMsg = exportSession.error?.localizedDescription ?? "未知错误"
            print("❌ 导出失败: \(errorMsg)")
            print("   状态: \(exportSession.status.rawValue)")
            throw TTSError.audioProcessingFailed
        }

        // 验证输出文件
        if let attrs = try? FileManager.default.attributesOfItem(atPath: outputURL.path),
           let fileSize = attrs[.size] as? Int64 {
            print("✅ 导出成功，文件大小: \(fileSize) 字节")
        }

        print("✅ 生成了 \(segments.count) 个时间戳段落")
        return segments
    }

    /// 实时播放（用于预览）
    func speak(text: String, voice: String, speed: Float = 1.0) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(identifier: voice)

        // 将倍速转换为 AVSpeechUtterance 的 rate 值
        // AVSpeechUtterance.rate 范围：0.0-1.0
        // 其中 AVSpeechUtteranceDefaultSpeechRate (约0.5) 是正常速度
        // 我们的倍速范围：0.5x-2.0x
        // 转换公式：rate = defaultRate * speed
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * speed

        synthesizer.speak(utterance)
        isSpeaking = true
    }

    /// 停止播放
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension TTSService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
    }
}

/// 对话结构
struct Dialogue {
    enum Speaker {
        case hostA
        case hostB
    }

    let speaker: Speaker
    let content: String
}

/// TTS 错误类型
enum TTSError: LocalizedError {
    case audioProcessingFailed
    case unsupportedEngine
    case apiError(String)
    case invalidURL
    case connectionFailed
    case invalidResponse
    case invalidVoice(String)
    case unsupportedPlatform

    var errorDescription: String? {
        switch self {
        case .audioProcessingFailed:
            return "音频处理失败"
        case .unsupportedEngine:
            return "不支持的 TTS 引擎"
        case .apiError(let message):
            return "TTS API 错误: \(message)"
        case .invalidURL:
            return "无效的URL"
        case .connectionFailed:
            return "连接失败"
        case .invalidResponse:
            return "无效的响应"
        case .invalidVoice(let message):
            return "音色配置错误: \(message)"
        case .unsupportedPlatform:
            return "不支持的平台"
        }
    }
}

/// 豆包 TTS API 响应
struct DoubaoTTSResponse: Codable {
    let code: Int?
    let message: String?
    let data: String? // Base64 编码的音频数据
}

/// TTS 引擎类型（用于 TTS 服务）
enum TTSEngine: String, Codable {
    case system = "macOS系统TTS"
    case doubaoTTS = "豆包语音合成2.0"
    case openai = "OpenAI TTS"
    case elevenlabs = "ElevenLabs"
    case doubaoPodcast = "豆包播客API（一体化）"

    /// 是否需要LLM生成对话脚本
    /// - 纯TTS引擎：需要先用LLM将原文转换为对话脚本，再用TTS合成音频
    /// - 一体化引擎：直接将原文发送给API，由API内部完成脚本生成和音频合成
    var needsScriptGeneration: Bool {
        switch self {
        case .system, .doubaoTTS, .openai, .elevenlabs:
            return true  // 纯TTS引擎，需要LLM生成脚本
        case .doubaoPodcast:
            return false // 一体化引擎，不需要LLM生成脚本
        }
    }

    /// 引擎类型描述
    var engineType: String {
        switch self {
        case .system, .doubaoTTS, .openai, .elevenlabs:
            return "纯TTS引擎"
        case .doubaoPodcast:
            return "一体化引擎"
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

/// 可用的系统语音
extension TTSService {
    static var availableVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("zh") }
    }

    static var defaultVoiceA: String {
        "com.apple.voice.compact.zh-CN.Tingting"
    }

    static var defaultVoiceB: String {
        "com.apple.voice.compact.zh-CN.Sinji"
    }
}
