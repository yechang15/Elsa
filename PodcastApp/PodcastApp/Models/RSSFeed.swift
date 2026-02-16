import Foundation
import SwiftData

/// RSS订阅源模型
@Model
final class RSSFeed {
    var id: UUID
    var url: String
    var title: String
    var lastUpdated: Date?
    var articleCount: Int
    var isActive: Bool

    // 关联的话题
    @Relationship(inverse: \Topic.rssFeeds)
    var topic: Topic?

    init(url: String, title: String, topic: Topic? = nil) {
        self.id = UUID()
        self.url = url
        self.title = title
        self.articleCount = 0
        self.isActive = true
        self.topic = topic
    }

    /// 更新状态文本
    var updateStatusText: String {
        guard let lastUpdated = lastUpdated else {
            return "未更新"
        }

        let interval = Date().timeIntervalSince(lastUpdated)
        let hours = Int(interval / 3600)

        if hours < 1 {
            return "刚刚更新"
        } else if hours < 24 {
            return "\(hours) 小时前更新"
        } else {
            let days = hours / 24
            return "\(days) 天前更新"
        }
    }
}

/// 预设RSS源
extension RSSFeed {
    static let presetFeeds: [String: [String]] = [
        "Swift 开发": [
            "https://www.swift.org/blog/rss.xml",
            "https://nshipster.com/feed.xml",
            "https://www.avanderlee.com/feed/"
        ],
        "AI 技术": [
            "https://openai.com/blog/rss/",
            "https://www.anthropic.com/rss.xml"
        ],
        "科技新闻": [
            "https://techcrunch.com/feed/",
            "https://www.theverge.com/rss/index.xml",
            "https://36kr.com/feed"
        ],
        "产品设计": [
            "https://www.smashingmagazine.com/feed/",
            "https://www.nngroup.com/feed/rss/"
        ]
    ]
}
