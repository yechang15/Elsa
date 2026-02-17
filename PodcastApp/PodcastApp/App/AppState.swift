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
    // LLM配置
    var llmProvider: String = "豆包"
    var llmApiKey: String = ""
    var llmModel: String = "doubao-seed-2-0-pro-260215"

    // TTS配置
    var ttsEngine: TTSEngine = .system
    var ttsSpeed: Double = 1.0
    var ttsVoiceA: String = "com.apple.voice.compact.zh-CN.Tingting"
    var ttsVoiceB: String = "com.apple.voice.compact.zh-CN.Sinji"

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

enum TTSEngine: String, Codable {
    case system = "macOS系统TTS"
    case openai = "OpenAI TTS"
    case elevenlabs = "ElevenLabs"
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
