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
        // 技术开发
        "Swift 开发",
        "前端开发",
        "后端架构",
        "移动开发",
        "AI 技术",
        "数据科学",
        "DevOps",
        "开源项目",
        "Web3 & 区块链",
        "云计算",

        // 产品与设计
        "产品设计",
        "UX 研究",
        "UI 设计",
        "交互设计",

        // 商业与创业
        "创业",
        "科技新闻",
        "商业分析",
        "投资理财",
        "营销增长",

        // 生活方式
        "健康养生",
        "心理学",
        "个人成长",
        "阅读写作",
        "播客推荐",

        // 娱乐文化
        "电影评论",
        "音乐推荐",
        "游戏资讯",
        "动漫二次元",

        // 科学探索
        "天文物理",
        "生物医学",
        "环境科学",
        "科普知识"
    ]
}
