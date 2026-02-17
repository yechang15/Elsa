import Foundation
import SwiftData

/// 播客模型
@Model
final class Podcast {
    var id: UUID
    var title: String
    var topics: [String] // 关联的话题标签
    var duration: Int // 时长（秒）
    var createdAt: Date
    var scriptContent: String // 播客脚本内容
    var audioFilePath: String? // 音频文件路径
    var playProgress: Double // 播放进度 (0.0-1.0)
    var isCompleted: Bool // 是否听完

    // 生成配置
    var length: Int // 目标长度（分钟）
    var contentDepth: String
    var hostStyle: String

    // RSS 来源信息
    var sourceArticles: [SourceArticle] = [] // 来源文章列表

    init(title: String, topics: [String], duration: Int, scriptContent: String, length: Int = 15, contentDepth: String = "快速浏览", hostStyle: String = "轻松闲聊", sourceArticles: [SourceArticle] = []) {
        self.id = UUID()
        self.title = title
        self.topics = topics
        self.duration = duration
        self.createdAt = Date()
        self.scriptContent = scriptContent
        self.playProgress = 0.0
        self.isCompleted = false
        self.length = length
        self.contentDepth = contentDepth
        self.hostStyle = hostStyle
        self.sourceArticles = sourceArticles
    }

    /// 格式化时长
    var formattedDuration: String {
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// 播放状态
    var playStatus: PlayStatus {
        if isCompleted {
            return .completed
        } else if playProgress > 0 {
            return .inProgress
        } else {
            return .notStarted
        }
    }
}

enum PlayStatus {
    case notStarted
    case inProgress
    case completed

    var displayText: String {
        switch self {
        case .notStarted: return "未听"
        case .inProgress: return "进行中"
        case .completed: return "已听完"
        }
    }
}

/// RSS 来源文章信息
struct SourceArticle: Codable {
    let title: String
    let link: String
    let description: String
    let pubDate: Date

    var formattedPubDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: pubDate, relativeTo: Date())
    }
}
