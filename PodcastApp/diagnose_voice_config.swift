#!/usr/bin/env swift

import Foundation

// 从VolcengineVoices.swift复制的音色定义
struct Voice {
    let id: String
    let name: String
    let resourceIds: [String]
}

let tts2Voices: [Voice] = [
    Voice(id: "zh_female_vv_uranus_bigtts", name: "Vivi 2.0", resourceIds: ["seed-tts-2.0"]),
    Voice(id: "zh_female_xiaohe_uranus_bigtts", name: "小何 2.0", resourceIds: ["seed-tts-2.0"]),
    Voice(id: "zh_male_m191_uranus_bigtts", name: "云舟 2.0", resourceIds: ["seed-tts-2.0"]),
    Voice(id: "zh_male_taocheng_uranus_bigtts", name: "小天 2.0", resourceIds: ["seed-tts-2.0"]),
    Voice(id: "zh_female_meilinvyou_saturn_bigtts", name: "魅力女友", resourceIds: ["seed-tts-2.0"]),
    Voice(id: "zh_male_dayi_saturn_bigtts", name: "大壹", resourceIds: ["seed-tts-2.0"]),
    Voice(id: "zh_female_santongyongns_saturn_bigtts", name: "流畅女声", resourceIds: ["seed-tts-2.0"]),
    Voice(id: "zh_male_ruyayichen_saturn_bigtts", name: "儒雅逸辰", resourceIds: ["seed-tts-2.0"]),
    Voice(id: "saturn_zh_female_keainvsheng_tob", name: "可爱女生", resourceIds: ["seed-tts-2.0"]),
    Voice(id: "saturn_zh_female_tiaopigongzhu_tob", name: "调皮公主", resourceIds: ["seed-tts-2.0"]),
    Voice(id: "saturn_zh_male_shuanglangshaonian_tob", name: "爽朗少年", resourceIds: ["seed-tts-2.0"]),
    Voice(id: "saturn_zh_male_tiancaitongzhuo_tob", name: "天才同桌", resourceIds: ["seed-tts-2.0"]),
]

let tts1Voices: [Voice] = [
    Voice(id: "zh_female_shuangkuaisisi_moon_bigtts", name: "双快思思", resourceIds: ["seed-tts-1.0", "seed-tts-1.0-concurr"]),
    Voice(id: "zh_male_wennuanahu_moon_bigtts", name: "温暖阿虎", resourceIds: ["seed-tts-1.0", "seed-tts-1.0-concurr"]),
]

print("=== 火山引擎TTS音色配置诊断工具 ===\n")

// 读取配置
if let data = UserDefaults.standard.data(forKey: "userConfig"),
   let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

    let resourceId = config["doubaoTTSResourceId"] as? String ?? "seed-tts-2.0"
    let voiceA = config["doubaoTTSVoiceA"] as? String ?? ""
    let voiceB = config["doubaoTTSVoiceB"] as? String ?? ""

    print("当前配置:")
    print("  Resource ID: \(resourceId)")
    print("  主播A音色: \(voiceA)")
    print("  主播B音色: \(voiceB)")
    print()

    // 检查音色是否匹配
    let allVoices = tts2Voices + tts1Voices
    let availableVoices = allVoices.filter { $0.resourceIds.contains(resourceId) }

    let voiceAValid = availableVoices.contains { $0.id == voiceA }
    let voiceBValid = availableVoices.contains { $0.id == voiceB }

    print("音色验证:")
    print("  主播A: \(voiceAValid ? "✅ 有效" : "❌ 无效")")
    print("  主播B: \(voiceBValid ? "✅ 有效" : "❌ 无效")")
    print()

    if !voiceAValid || !voiceBValid {
        print("⚠️ 检测到音色配置错误！")
        print()
        print("可用的音色列表（Resource ID: \(resourceId)）:")
        for voice in availableVoices {
            print("  • \(voice.name) (\(voice.id))")
        }
        print()
        print("建议修复:")
        print("  1. 打开应用的设置页面")
        print("  2. 在TTS配置中点击「重置音色配置」按钮")
        print("  3. 或手动选择上述列表中的音色")
    } else {
        print("✅ 音色配置正确")
    }
} else {
    print("❌ 无法读取配置文件")
}
