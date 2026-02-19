#!/usr/bin/env swift

import Foundation
import AVFoundation

#if os(macOS)
import AppKit
#endif

/// 测试系统 TTS 功能
/// 使用方法：swift SystemTTSTest.swift

print("=== 系统 TTS 测试 ===\n")

// 1. 列出可用的中文语音
print("1. 可用的中文语音：")
let chineseVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("zh") }
for (index, voice) in chineseVoices.enumerated() {
    print("   \(index + 1). \(voice.name) (\(voice.identifier))")
    print("      语言: \(voice.language), 质量: \(voice.quality.rawValue)")
}

// 2. 测试基本的 TTS 功能
print("\n2. 测试基本 TTS 功能：")
print("   正在合成测试音频...")

let testText = "你好，这是一个系统TTS测试。欢迎使用播客应用。"
let voiceId = chineseVoices.first?.identifier ?? "com.apple.voice.compact.zh-CN.Tingting"

print("   使用音色: \(voiceId)")
print("   文本: \(testText)")

// 创建临时文件
let tempDir = FileManager.default.temporaryDirectory
let outputURL = tempDir.appendingPathComponent("tts_test_\(UUID().uuidString).caf")

print("   输出文件: \(outputURL.path)")

// 使用 AVSpeechSynthesizer.write() 方法
let semaphore = DispatchSemaphore(value: 0)
var synthesisError: Error?

let audioEngine = AVAudioEngine()
let speechSynthesizer = AVSpeechSynthesizer()
let playerNode = AVAudioPlayerNode()

// 配置音频引擎
audioEngine.attach(playerNode)
audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: nil)

// 创建音频文件
let sampleRate: Double = 44100.0
let format = AVAudioFormat(
    commonFormat: .pcmFormatFloat32,
    sampleRate: sampleRate,
    channels: 1,
    interleaved: false
)!

guard let audioFile = try? AVAudioFile(forWriting: outputURL, settings: format.settings) else {
    print("❌ 无法创建音频文件")
    exit(1)
}

// 安装 tap 来录制音频
audioEngine.mainMixerNode.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
    do {
        try audioFile.write(from: buffer)
    } catch {
        print("❌ 写入音频缓冲失败: \(error)")
    }
}

// 启动音频引擎
do {
    try audioEngine.start()
    playerNode.play()
} catch {
    print("❌ 启动音频引擎失败: \(error)")
    exit(1)
}

// 配置语音
let utterance = AVSpeechUtterance(string: testText)
utterance.voice = AVSpeechSynthesisVoice(identifier: voiceId)
utterance.rate = AVSpeechUtteranceDefaultSpeechRate

// 设置 delegate
class TestDelegate: NSObject, AVSpeechSynthesizerDelegate {
    let semaphore: DispatchSemaphore
    let audioEngine: AVAudioEngine
    let playerNode: AVAudioPlayerNode

    init(semaphore: DispatchSemaphore, audioEngine: AVAudioEngine, playerNode: AVAudioPlayerNode) {
        self.semaphore = semaphore
        self.audioEngine = audioEngine
        self.playerNode = playerNode
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("   ✅ 合成完成")
        Thread.sleep(forTimeInterval: 0.2)
        audioEngine.mainMixerNode.removeTap(onBus: 0)
        playerNode.stop()
        audioEngine.stop()
        semaphore.signal()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("   ❌ 合成被取消")
        audioEngine.mainMixerNode.removeTap(onBus: 0)
        playerNode.stop()
        audioEngine.stop()
        semaphore.signal()
    }
}

let delegate = TestDelegate(semaphore: semaphore, audioEngine: audioEngine, playerNode: playerNode)
speechSynthesizer.delegate = delegate

// 使用 write 方法获取音频缓冲并播放
speechSynthesizer.write(utterance) { buffer in
    guard let pcmBuffer = buffer as? AVAudioPCMBuffer else { return }
    playerNode.scheduleBuffer(pcmBuffer)
}

// 等待完成
semaphore.wait()

// 3. 验证输出文件
print("\n3. 验证输出文件：")
if FileManager.default.fileExists(atPath: outputURL.path) {
    if let attrs = try? FileManager.default.attributesOfItem(atPath: outputURL.path),
       let fileSize = attrs[.size] as? Int64 {
        print("   ✅ 文件已生成")
        print("   文件大小: \(fileSize) 字节")

        // 验证音频文件
        let asset = AVURLAsset(url: outputURL)
        let semaphore2 = DispatchSemaphore(value: 0)

        Task {
            do {
                let tracks = try await asset.loadTracks(withMediaType: .audio)
                if !tracks.isEmpty {
                    let duration = try await asset.load(.duration)
                    print("   音频时长: \(CMTimeGetSeconds(duration)) 秒")
                    print("   音频轨道数: \(tracks.count)")
                } else {
                    print("   ⚠️ 警告：音频文件无效，没有音频轨道")
                }
            } catch {
                print("   ❌ 验证音频文件失败: \(error)")
            }
            semaphore2.signal()
        }

        semaphore2.wait()
    }
} else {
    print("   ❌ 文件未生成")
}

print("\n=== 测试完成 ===")
print("输出文件路径: \(outputURL.path)")
print("你可以使用以下命令播放音频：")
print("afplay \"\(outputURL.path)\"")
