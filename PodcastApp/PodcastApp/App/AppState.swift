import SwiftUI

/// 应用全局状态
class AppState: ObservableObject {
    // 是否首次启动
    @Published var isFirstLaunch: Bool

    // 当前选中的导航项
    @Published var selectedNavigation: NavigationItem = .podcastList

    // 用户配置
    @Published var userConfig: UserConfig

    init() {
        // 从UserDefaults读取配置
        self.isFirstLaunch = UserDefaults.standard.bool(forKey: "isFirstLaunch") == false

        // 加载用户配置
        if let data = UserDefaults.standard.data(forKey: "userConfig"),
           let config = try? JSONDecoder().decode(UserConfig.self, from: data) {
            self.userConfig = config
        } else {
            self.userConfig = UserConfig()
        }
    }

    /// 完成首次启动
    func completeOnboarding() {
        isFirstLaunch = false
        UserDefaults.standard.set(true, forKey: "isFirstLaunch")
    }

    /// 保存用户配置
    func saveConfig() {
        if let data = try? JSONEncoder().encode(userConfig) {
            UserDefaults.standard.set(data, forKey: "userConfig")
        }
    }
}

/// 导航项
enum NavigationItem: String, CaseIterable {
    case podcastList = "播客列表"
    case topics = "兴趣话题"
    case rss = "RSS订阅"
    case history = "收听历史"
    case settings = "设置"

    var icon: String {
        switch self {
        case .podcastList: return "headphones"
        case .topics: return "target"
        case .rss: return "antenna.radiowaves.left.and.right"
        case .history: return "chart.bar"
        case .settings: return "gearshape"
        }
    }
}

/// 用户配置
struct UserConfig: Codable, Equatable {
    // LLM配置（用于脚本生成等功能）
    var llmProvider: String = "豆包"
    var llmApiKey: String = ""
    var llmModel: String = "doubao-seed-2-0-pro-260215"

    // TTS配置
    var ttsEngine: TTSEngine = .system

    // 系统TTS配置
    var ttsVoiceA: String = "com.apple.voice.compact.zh-CN.Tingting"
    var ttsSpeedA: Double = 1.0
    var ttsTestTextA: String = "大家好，我是主播A，今天咱们聊聊Swift的异步编程特性。"
    var ttsVoiceB: String = "com.apple.voice.compact.zh-CN.Sinji"
    var ttsSpeedB: Double = 1.0
    var ttsTestTextB: String = "大家好，我是主播B，这个话题确实很有意思呢！"

    // OpenAI TTS配置
    var openaiTTSApiKey: String = ""
    var openaiTTSModel: String = "tts-1"
    var openaiTTSVoiceA: String = "alloy"
    var openaiTTSVoiceB: String = "echo"

    // 豆包 TTS 配置（双向流式）
    var doubaoTTSApiKey: String = "" // 新版API Key (UUID格式) 或 旧版App ID
    var doubaoTTSAccessToken: String = "" // 仅旧版需要
    var doubaoTTSResourceId: String = "seed-tts-2.0"
    var doubaoTTSVoiceA: String = "zh_female_tianmeixiaoyuan"
    var doubaoTTSVoiceB: String = "zh_male_aojiaobazong"

    // ElevenLabs TTS配置
    var elevenlabsApiKey: String = ""
    var elevenlabsVoiceA: String = ""
    var elevenlabsVoiceB: String = ""

    // 豆包播客API配置（一体化模式）
    var doubaoPodcastAppId: String = ""
    var doubaoPodcastAccessToken: String = ""
    var doubaoPodcastVoiceA: String = "zh_female_shuangkuaisisi_moon_bigtts"
    var doubaoPodcastVoiceB: String = "zh_male_wennuanahu_moon_bigtts"

    // 播客生成配置
    var defaultLength: Int = 15 // 分钟
    var contentDepth: ContentDepth = .quick
    var hostStyle: HostStyle = .casual
    var autoGenerate: Bool = true
    var autoGenerateTime: String = "08:00"

    // 通知配置
    var notifyNewPodcast: Bool = true
    var notifyRSSUpdate: Bool = true

    // 外观配置
    var theme: AppTheme = .system
}

enum ContentDepth: String, Codable {
    case quick = "快速浏览"
    case detailed = "深度分析"
}

enum HostStyle: String, Codable {
    case casual = "轻松闲聊"
    case serious = "严肃分析"
    case humorous = "幽默吐槽"
}

enum AppTheme: String, Codable {
    case system = "跟随系统"
    case light = "浅色"
    case dark = "深色"
}
