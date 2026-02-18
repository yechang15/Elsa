#!/usr/bin/env swift

import Foundation

// 模拟音色数据
struct Voice {
    let id: String
    let name: String
}

let voices = [
    Voice(id: "zh_female_xiaohe_uranus_bigtts", name: "小何 2.0"),
    Voice(id: "zh_male_taocheng_uranus_bigtts", name: "小天 2.0"),
    Voice(id: "zh_female_vv_uranus_bigtts", name: "Vivi 2.0"),
    Voice(id: "zh_male_m191_uranus_bigtts", name: "云舟 2.0"),
    Voice(id: "zh_female_shuangkuaisisi_moon_bigtts", name: "双快思思"),
    Voice(id: "zh_male_wennuanahu_moon_bigtts", name: "温暖阿虎"),
]

func extractVoiceName(from voiceId: String) -> String {
    if let voice = voices.first(where: { $0.id == voiceId }) {
        let name = voice.name
        if let firstPart = name.components(separatedBy: " ").first {
            return firstPart
        }
        return name
    }
    return "主播"
}

print("=== 主播名称提取测试 ===\n")

for voice in voices {
    let extractedName = extractVoiceName(from: voice.id)
    print("音色: \(voice.name)")
    print("  ID: \(voice.id)")
    print("  提取的名称: \(extractedName)")
    print()
}

print("=== 脚本解析测试 ===\n")

let testScripts = [
    "主播A：大家好，我是主播A",
    "主播B：大家好，我是主播B",
    "小何：大家好，我是小何",
    "云舟：大家好，我是云舟",
    "Vivi：Hello, I'm Vivi",
]

for script in testScripts {
    if let colonIndex = script.firstIndex(where: { $0 == "：" || $0 == ":" }) {
        let speakerName = String(script[..<colonIndex])
        let content = String(script[script.index(after: colonIndex)...])
        print("原文: \(script)")
        print("  主播: \(speakerName)")
        print("  内容: \(content)")
        print()
    }
}

print("✅ 测试完成！")
