import Foundation
import SwiftData

/// 兴趣话题模型
@Model
final class Topic {
    var id: UUID
    var name: String
    var priority: Int // 优先级，数字越大优先级越高
    var createdAt: Date
    var lastGeneratedAt: Date?

    // 关联的RSS源
    @Relationship(deleteRule: .cascade)
    var rssFeeds: [RSSFeed] = []

    init(name: String, priority: Int = 0) {
        self.id = UUID()
        self.name = name
        self.priority = priority
        self.createdAt = Date()
    }
}

/// 预设话题列表
extension Topic {
    static let presetTopics = [
        "Swift 开发",
        "产品设计",
        "AI 技术",
        "创业",
        "前端开发",
        "UX 研究",
        "后端架构",
        "数据科学",
        "移动开发",
        "开源项目",
        "DevOps",
        "科技新闻"
    ]
}
