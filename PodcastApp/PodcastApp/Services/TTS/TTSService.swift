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
    func generateAudio(script: String, voiceA: String, voiceB: String, speed: Float = 1.0) async throws -> URL {
        // 解析脚本
        let dialogues = parseScript(script)

        // 创建临时音频文件
        let tempDir = FileManager.default.temporaryDirectory
        let audioFileName = "podcast_\(UUID().uuidString).m4a"
        let audioURL = tempDir.appendingPathComponent(audioFileName)

        // 使用AVAudioEngine合成音频
        try await synthesizeToFile(dialogues: dialogues, voiceA: voiceA, voiceB: voiceB, speed: speed, outputURL: audioURL)

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

    /// 合成音频到文件
    private func synthesizeToFile(dialogues: [Dialogue], voiceA: String, voiceB: String, speed: Float, outputURL: URL) async throws {
        // 使用系统TTS合成
        // 注意：这是简化版本，实际需要使用AVAudioEngine进行音频拼接
        // 完整实现需要：
        // 1. 为每段对话生成音频
        // 2. 使用AVAudioEngine拼接音频
        // 3. 导出为单个文件

        // 这里先返回一个占位实现
        // 实际项目中需要完整的音频处理逻辑
        try "placeholder".write(to: outputURL, atomically: true, encoding: .utf8)
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
