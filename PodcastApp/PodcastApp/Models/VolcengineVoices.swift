import Foundation

/// 火山引擎TTS音色定义
struct VolcengineVoice: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let gender: Gender
    let resourceIds: [String]

    enum Gender {
        case female
        case male
    }

    var displayName: String {
        "\(name) - \(description)"
    }
}

/// 火山引擎TTS音色列表
struct VolcengineVoices {
    // seed-tts-2.0 音色
    static let tts2Voices: [VolcengineVoice] = [
        // 通用场景
        VolcengineVoice(
            id: "zh_female_vv_uranus_bigtts",
            name: "Vivi 2.0",
            description: "通用女声，支持中英日等多语言",
            gender: .female,
            resourceIds: ["seed-tts-2.0"]
        ),
        VolcengineVoice(
            id: "zh_female_xiaohe_uranus_bigtts",
            name: "小何 2.0",
            description: "通用女声，自然流畅",
            gender: .female,
            resourceIds: ["seed-tts-2.0"]
        ),
        VolcengineVoice(
            id: "zh_male_m191_uranus_bigtts",
            name: "云舟 2.0",
            description: "通用男声，沉稳大气",
            gender: .male,
            resourceIds: ["seed-tts-2.0"]
        ),
        VolcengineVoice(
            id: "zh_male_taocheng_uranus_bigtts",
            name: "小天 2.0",
            description: "通用男声，年轻活力",
            gender: .male,
            resourceIds: ["seed-tts-2.0"]
        ),

        // 视频配音场景
        VolcengineVoice(
            id: "zh_female_meilinvyou_saturn_bigtts",
            name: "魅力女友",
            description: "视频配音，温柔甜美",
            gender: .female,
            resourceIds: ["seed-tts-2.0"]
        ),
        VolcengineVoice(
            id: "zh_male_dayi_saturn_bigtts",
            name: "大壹",
            description: "视频配音，磁性男声",
            gender: .male,
            resourceIds: ["seed-tts-2.0"]
        ),
        VolcengineVoice(
            id: "zh_female_santongyongns_saturn_bigtts",
            name: "流畅女声",
            description: "视频配音，清晰流畅",
            gender: .female,
            resourceIds: ["seed-tts-2.0"]
        ),
        VolcengineVoice(
            id: "zh_male_ruyayichen_saturn_bigtts",
            name: "儒雅逸辰",
            description: "视频配音，儒雅知性",
            gender: .male,
            resourceIds: ["seed-tts-2.0"]
        ),

        // 角色扮演场景
        VolcengineVoice(
            id: "saturn_zh_female_keainvsheng_tob",
            name: "可爱女生",
            description: "角色扮演，活泼可爱",
            gender: .female,
            resourceIds: ["seed-tts-2.0"]
        ),
        VolcengineVoice(
            id: "saturn_zh_female_tiaopigongzhu_tob",
            name: "调皮公主",
            description: "角色扮演，俏皮灵动",
            gender: .female,
            resourceIds: ["seed-tts-2.0"]
        ),
        VolcengineVoice(
            id: "saturn_zh_male_shuanglangshaonian_tob",
            name: "爽朗少年",
            description: "角色扮演，阳光开朗",
            gender: .male,
            resourceIds: ["seed-tts-2.0"]
        ),
        VolcengineVoice(
            id: "saturn_zh_male_tiancaitongzhuo_tob",
            name: "天才同桌",
            description: "角色扮演，聪明睿智",
            gender: .male,
            resourceIds: ["seed-tts-2.0"]
        ),
    ]

    // seed-tts-1.0 音色（示例，可根据需要补充）
    static let tts1Voices: [VolcengineVoice] = [
        VolcengineVoice(
            id: "zh_female_shuangkuaisisi_moon_bigtts",
            name: "双快思思",
            description: "通用女声",
            gender: .female,
            resourceIds: ["seed-tts-1.0", "seed-tts-1.0-concurr"]
        ),
        VolcengineVoice(
            id: "zh_male_wennuanahu_moon_bigtts",
            name: "温暖阿虎",
            description: "通用男声",
            gender: .male,
            resourceIds: ["seed-tts-1.0", "seed-tts-1.0-concurr"]
        ),
    ]

    /// 根据Resource ID获取可用音色
    static func voices(for resourceId: String) -> [VolcengineVoice] {
        let allVoices = tts2Voices + tts1Voices
        return allVoices.filter { $0.resourceIds.contains(resourceId) }
    }

    /// 获取女声音色
    static func femaleVoices(for resourceId: String) -> [VolcengineVoice] {
        voices(for: resourceId).filter { $0.gender == .female }
    }

    /// 获取男声音色
    static func maleVoices(for resourceId: String) -> [VolcengineVoice] {
        voices(for: resourceId).filter { $0.gender == .male }
    }
}
