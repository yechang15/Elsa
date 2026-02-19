#!/usr/bin/env swift

import Foundation
import AppKit

/// 简单的 NSSpeechSynthesizer 测试
print("=== macOS 系统 TTS 测试 (NSSpeechSynthesizer) ===\n")

// 1. 列出可用的语音
print("1. 可用的语音：")
let voices = NSSpeechSynthesizer.availableVoices
for (index, voice) in voices.enumerated() {
    let attributes = NSSpeechSynthesizer.attributes(forVoice: voice)
    let name = attributes[.name] as? String ?? "Unknown"
    let language = attributes[.localeIdentifier] as? String ?? "Unknown"

    // 只显示中文语音
    if language.hasPrefix("zh") {
        print("   \(index + 1). \(name) (\(voice.rawValue))")
        print("      语言: \(language)")
    }
}

// 2. 测试合成
print("\n2. 测试语音合成：")
let testText = "你好，这是一个系统TTS测试。欢迎使用播客应用。"
let voiceId = "com.apple.voice.compact.zh-CN.Tingting"

print("   使用音色: \(voiceId)")
print("   文本: \(testText)")

// 创建临时文件
let tempDir = FileManager.default.temporaryDirectory
let outputURL = tempDir.appendingPathComponent("tts_test_\(UUID().uuidString).aiff")

print("   输出文件: \(outputURL.path)")

// 创建 synthesizer
let synthesizer = NSSpeechSynthesizer()

// 设置音色
let voice = NSSpeechSynthesizer.VoiceName(rawValue: voiceId)
synthesizer.setVoice(voice)
print("   ✅ 音色设置成功")

// 设置语速
synthesizer.rate = 200.0  // 默认速度

// 开始合成
print("   开始合成...")
let success = synthesizer.startSpeaking(testText, to: outputURL)

if success {
    print("   ✅ 合成已启动")

    // 等待完成
    while synthesizer.isSpeaking {
        Thread.sleep(forTimeInterval: 0.1)
    }

    print("   ✅ 合成完成")

    // 3. 验证文件
    print("\n3. 验证输出文件：")
    if FileManager.default.fileExists(atPath: outputURL.path) {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: outputURL.path),
           let fileSize = attrs[.size] as? Int64 {
            print("   ✅ 文件已生成")
            print("   文件大小: \(fileSize) 字节")
            print("   文件路径: \(outputURL.path)")

            print("\n=== 测试成功 ===")
            print("你可以使用以下命令播放音频：")
            print("afplay \"\(outputURL.path)\"")
        }
    } else {
        print("   ❌ 文件未生成")
    }
} else {
    print("   ❌ 合成启动失败")
}
