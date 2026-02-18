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
        if let data = UserDefaults.standard.data(forKey: "userConfig") {
            do {
                self.userConfig = try JSONDecoder().decode(UserConfig.self, from: data)

                // 强制检查并修复音色配置
                var needsSave = false
                if self.userConfig.doubaoTTSVoiceA == "zh_female_tianmeixiaoyuan" {
                    print("⚠️ 修复主播A音色配置")
                    self.userConfig.doubaoTTSVoiceA = "zh_female_xiaohe_uranus_bigtts"
                    needsSave = true
                }
                if self.userConfig.doubaoTTSVoiceB == "zh_male_aojiaobazong" {
                    print("⚠️ 修复主播B音色配置")
                    self.userConfig.doubaoTTSVoiceB = "zh_male_taocheng_uranus_bigtts"
                    needsSave = true
                }

                if needsSave {
                    // 立即保存修复后的配置
                    if let fixedData = try? JSONEncoder().encode(self.userConfig) {
                        UserDefaults.standard.set(fixedData, forKey: "userConfig")
                        print("✅ 音色配置已自动修复并保存")
                    }
                }
            } catch {
                print("⚠️ 配置解码失败: \(error)")
                print("⚠️ 尝试迁移旧配置...")

                // 尝试保留旧的API Key等重要信息
                if let oldDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    var newConfig = UserConfig()

                    // 迁移重要字段
                    if let llmApiKey = oldDict["llmApiKey"] as? String {
                        newConfig.llmApiKey = llmApiKey
                    }
                    if let llmProvider = oldDict["llmProvider"] as? String {
                        newConfig.llmProvider = llmProvider
                    }
                    if let llmModel = oldDict["llmModel"] as? String {
                        newConfig.llmModel = llmModel
                    }
                    if let doubaoTTSApiKey = oldDict["doubaoTTSApiKey"] as? String {
                        newConfig.doubaoTTSApiKey = doubaoTTSApiKey
                    }
                    if let doubaoTTSAccessToken = oldDict["doubaoTTSAccessToken"] as? String {
                        newConfig.doubaoTTSAccessToken = doubaoTTSAccessToken
                    }
                    if let doubaoTTSResourceId = oldDict["doubaoTTSResourceId"] as? String {
                        newConfig.doubaoTTSResourceId = doubaoTTSResourceId
                    }

                    // 迁移音色配置，但要检查兼容性
                    if let voiceA = oldDict["doubaoTTSVoiceA"] as? String {
                        // 检查是否是旧的不兼容音色
                        if voiceA == "zh_female_tianmeixiaoyuan" || voiceA == "zh_male_aojiaobazong" {
                            print("⚠️ 检测到旧的音色配置，使用新的默认值")
                            // 使用新的默认值（已在UserConfig中定义）
                        } else {
                            newConfig.doubaoTTSVoiceA = voiceA
                        }
                    }

                    if let voiceB = oldDict["doubaoTTSVoiceB"] as? String {
                        if voiceB == "zh_female_tianmeixiaoyuan" || voiceB == "zh_male_aojiaobazong" {
                            print("⚠️ 检测到旧的音色配置，使用新的默认值")
                        } else {
                            newConfig.doubaoTTSVoiceB = voiceB
                        }
                    }
                    if let openaiTTSApiKey = oldDict["openaiTTSApiKey"] as? String {
                        newConfig.openaiTTSApiKey = openaiTTSApiKey
                    }

                    print("✅ 已迁移部分配置")
                    self.userConfig = newConfig
                } else {
                    print("❌ 无法迁移旧配置，使用默认配置")
                    self.userConfig = UserConfig()
                }
            }
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
    var doubaoTTSVoiceA: String = "zh_female_xiaohe_uranus_bigtts"  // 小何 2.0 - 通用女声
    var doubaoTTSVoiceB: String = "zh_male_taocheng_uranus_bigtts"  // 小天 2.0 - 通用男声

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
    var autoGenerateFrequency: AutoGenerateFrequency = .daily // 生成频率
    var autoGenerateTopics: [String] = [] // 自动生成的话题ID列表

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

enum AutoGenerateFrequency: String, Codable, CaseIterable {
    case daily = "每天"
    case weekdays = "工作日"
    case weekends = "周末"
    case custom = "自定义"

    var description: String {
        switch self {
        case .daily:
            return "每天生成"
        case .weekdays:
            return "周一至周五生成"
        case .weekends:
            return "周六、周日生成"
        case .custom:
            return "自定义周期"
        }
    }
}

enum AppTheme: String, Codable {
    case system = "跟随系统"
    case light = "浅色"
    case dark = "深色"
}
