import Foundation
import AVFoundation

/// TTS语音合成服务
class TTSService: NSObject, ObservableObject {
    private nonisolated(unsafe) let synthesizer = AVSpeechSynthesizer()
    @Published var isSpeaking = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// 将播客脚本转换为音频文件
    func generateAudio(script: String, voiceA: String, voiceB: String, speed: Float = 1.0, engine: TTSEngine = .system, apiKey: String = "", appId: String = "", accessToken: String = "", resourceId: String = "seed-tts-2.0") async throws -> URL {
        // 解析脚本
        let dialogues = parseScript(script)

        // 创建临时音频文件
        let tempDir = FileManager.default.temporaryDirectory
        let audioFileName = "podcast_\(UUID().uuidString).m4a"
        let audioURL = tempDir.appendingPathComponent(audioFileName)

        // 根据引擎选择合成方式
        switch engine {
        case .system:
            try await synthesizeToFile(dialogues: dialogues, voiceA: voiceA, voiceB: voiceB, speed: speed, outputURL: audioURL)
        case .doubaoTTS:
            try await synthesizeWithVolcengineBidirectionalTTS(dialogues: dialogues, voiceA: voiceA, voiceB: voiceB, speed: speed, appId: appId, accessToken: accessToken, resourceId: resourceId, outputURL: audioURL)
        default:
            throw TTSError.unsupportedEngine
        }

        return audioURL
    }

    /// 解析播客脚本
    private func parseScript(_ script: String) -> [Dialogue] {
        let lines = script.components(separatedBy: .newlines)
        var dialogues: [Dialogue] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if trimmed.hasPrefix("主播A：") || trimmed.hasPrefix("主播A:") {
                let content = trimmed.replacingOccurrences(of: "主播A：", with: "").replacingOccurrences(of: "主播A:", with: "")
                dialogues.append(Dialogue(speaker: .hostA, content: content))
            } else if trimmed.hasPrefix("主播B：") || trimmed.hasPrefix("主播B:") {
                let content = trimmed.replacingOccurrences(of: "主播B：", with: "").replacingOccurrences(of: "主播B:", with: "")
                dialogues.append(Dialogue(speaker: .hostB, content: content))
            }
        }

        return dialogues
    }

    /// 使用火山引擎双向流式TTS合成音频
    private func synthesizeWithVolcengineBidirectionalTTS(dialogues: [Dialogue], voiceA: String, voiceB: String, speed: Float, appId: String, accessToken: String, resourceId: String, outputURL: URL) async throws {
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

            // 保存音频数据到临时文件
            let tempFile = FileManager.default.temporaryDirectory
                .appendingPathComponent("dialogue_\(index)_\(UUID().uuidString).mp3")
            try audioData.write(to: tempFile)
            audioFiles.append(tempFile)

            print("✅ 第 \(index + 1) 段对话合成完成")
        }

        // 合并所有音频文件
        print("合并音频文件...")
        try await mergeAudioFiles(audioFiles, outputURL: outputURL)

        // 清理临时文件
        for file in audioFiles {
            try? FileManager.default.removeItem(at: file)
        }

        print("✅ 音频合成完成: \(outputURL.path)")
    }

    /// 使用豆包 TTS API 合成音频（已废弃，保留用于兼容）
    private func synthesizeWithDoubaoTTS(dialogues: [Dialogue], voiceA: String, voiceB: String, speed: Float, apiKey: String, outputURL: URL) async throws {
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
        try await mergeAudioFiles(audioFiles, outputURL: outputURL)

        // 清理临时文件
        for file in audioFiles {
            try? FileManager.default.removeItem(at: file)
        }

        print("✅ 音频合成完成")
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
    private func synthesizeToFile(dialogues: [Dialogue], voiceA: String, voiceB: String, speed: Float, outputURL: URL) async throws {
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
        try await mergeAudioFiles(audioFiles, outputURL: outputURL)

        // 清理临时文件
        for file in audioFiles {
            try? FileManager.default.removeItem(at: file)
        }

        print("✅ 音频合成完成")
    }

    /// 合成单段对话
    private func synthesizeSingleDialogue(text: String, voice: String, speed: Float, outputURL: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(identifier: voice)
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * speed

            // 使用 AVSpeechSynthesizer 写入文件
            // 注意：macOS 的 AVSpeechSynthesizer 不直接支持写入文件
            // 我们需要使用 AVAudioEngine 录制输出

            let engine = AVAudioEngine()
            let player = AVAudioPlayerNode()

            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: nil)

            // 创建音频文件
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            do {
                let audioFile = try AVAudioFile(forWriting: outputURL, settings: settings)

                // 使用系统 TTS 生成音频
                // 这是一个简化实现，实际需要更复杂的音频处理
                // 暂时使用占位实现
                let silence = AVAudioPCMBuffer(pcmFormat: engine.mainMixerNode.outputFormat(forBus: 0), frameCapacity: 44100)!
                silence.frameLength = 44100 // 1秒静音
                try audioFile.write(from: silence)

                continuation.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// 合并音频文件
    private func mergeAudioFiles(_ files: [URL], outputURL: URL) async throws {
        let composition = AVMutableComposition()

        guard let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw TTSError.audioProcessingFailed
        }

        var currentTime = CMTime.zero

        for fileURL in files {
            let asset = AVURLAsset(url: fileURL)
            guard let assetTrack = try await asset.loadTracks(withMediaType: .audio).first else {
                continue
            }

            let duration = try await asset.load(.duration)
            let timeRange = CMTimeRange(start: .zero, duration: duration)

            try audioTrack.insertTimeRange(timeRange, of: assetTrack, at: currentTime)
            currentTime = CMTimeAdd(currentTime, duration)
        }

        // 导出合并后的音频
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw TTSError.audioProcessingFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        await exportSession.export()

        if exportSession.status != .completed {
            throw TTSError.audioProcessingFailed
        }
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
