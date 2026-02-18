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
        // 技术开发
        "Swift 开发": [
            "https://www.swift.org/blog/rss.xml",
            "https://nshipster.com/feed.xml",
            "https://www.avanderlee.com/feed/",
            "https://www.swiftbysundell.com/feed.xml"
        ],
        "前端开发": [
            "https://css-tricks.com/feed/",
            "https://www.smashingmagazine.com/feed/",
            "https://dev.to/feed",
            "https://javascript.plainenglish.io/feed"
        ],
        "后端架构": [
            "https://martinfowler.com/feed.atom",
            "https://www.infoq.com/feed/",
            "https://netflixtechblog.com/feed",
            "https://engineering.fb.com/feed/"
        ],
        "移动开发": [
            "https://android-developers.googleblog.com/feeds/posts/default",
            "https://developer.apple.com/news/rss/news.rss",
            "https://flutter.dev/feed.xml"
        ],
        "AI 技术": [
            "https://openai.com/blog/rss/",
            "https://www.anthropic.com/rss.xml",
            "https://ai.googleblog.com/feeds/posts/default",
            "https://blogs.nvidia.com/feed/"
        ],
        "数据科学": [
            "https://towardsdatascience.com/feed",
            "https://www.kdnuggets.com/feed",
            "https://machinelearningmastery.com/feed/"
        ],
        "DevOps": [
            "https://www.infoq.com/devops/feed/",
            "https://devops.com/feed/",
            "https://kubernetes.io/feed.xml"
        ],
        "开源项目": [
            "https://github.blog/feed/",
            "https://opensource.com/feed",
            "https://www.linuxfoundation.org/feed/"
        ],
        "Web3 & 区块链": [
            "https://blog.ethereum.org/feed.xml",
            "https://www.coindesk.com/arc/outboundfeeds/rss/",
            "https://decrypt.co/feed"
        ],
        "云计算": [
            "https://aws.amazon.com/blogs/aws/feed/",
            "https://cloud.google.com/blog/rss",
            "https://azure.microsoft.com/en-us/blog/feed/"
        ],

        // 产品与设计
        "产品设计": [
            "https://www.smashingmagazine.com/feed/",
            "https://www.nngroup.com/feed/rss/",
            "https://medium.com/feed/tag/product-design"
        ],
        "UX 研究": [
            "https://www.nngroup.com/feed/rss/",
            "https://uxdesign.cc/feed",
            "https://www.uxmatters.com/index.xml"
        ],
        "UI 设计": [
            "https://www.smashingmagazine.com/feed/",
            "https://dribbble.com/stories.rss",
            "https://www.awwwards.com/blog/feed/"
        ],
        "交互设计": [
            "https://www.interaction-design.org/literature/rss",
            "https://uxdesign.cc/feed"
        ],

        // 商业与创业
        "创业": [
            "https://techcrunch.com/category/startups/feed/",
            "https://36kr.com/feed",
            "https://www.ycombinator.com/blog/feed"
        ],
        "科技新闻": [
            "https://techcrunch.com/feed/",
            "https://www.theverge.com/rss/index.xml",
            "https://36kr.com/feed",
            "https://www.geekpark.net/rss",
            "https://sspai.com/feed"
        ],
        "商业分析": [
            "https://hbr.org/feed",
            "https://www.mckinsey.com/featured-insights/rss",
            "https://www.economist.com/rss"
        ],
        "投资理财": [
            "https://www.bloomberg.com/feed/podcast/money-stuff.xml",
            "https://www.ft.com/rss/home",
            "https://www.wsj.com/xml/rss/3_7085.xml"
        ],
        "营销增长": [
            "https://moz.com/blog/feed",
            "https://neilpatel.com/feed/",
            "https://www.growthhackers.com/feed"
        ],

        // 生活方式
        "健康养生": [
            "https://www.healthline.com/rss",
            "https://www.medicalnewstoday.com/rss",
            "https://www.webmd.com/rss/rss.aspx"
        ],
        "心理学": [
            "https://www.psychologytoday.com/us/blog/feed",
            "https://www.apa.org/news/rss/index.xml"
        ],
        "个人成长": [
            "https://zenhabits.net/feed/",
            "https://www.lifehack.org/feed",
            "https://tinybuddha.com/feed/"
        ],
        "阅读写作": [
            "https://lithub.com/feed/",
            "https://www.writersdigest.com/feed",
            "https://www.goodreads.com/blog.xml"
        ],
        "播客推荐": [
            "https://podnews.net/rss",
            "https://www.hotpodnews.com/feed"
        ],

        // 娱乐文化
        "电影评论": [
            "https://www.rottentomatoes.com/rss/",
            "https://www.imdb.com/news/rss/",
            "https://www.indiewire.com/feed/"
        ],
        "音乐推荐": [
            "https://pitchfork.com/rss/",
            "https://www.rollingstone.com/music/feed/",
            "https://www.billboard.com/feed/"
        ],
        "游戏资讯": [
            "https://www.ign.com/feed.xml",
            "https://www.gamespot.com/feeds/news/",
            "https://www.polygon.com/rss/index.xml"
        ],
        "动漫二次元": [
            "https://www.crunchyroll.com/feed",
            "https://www.animenewsnetwork.com/rss.xml"
        ],

        // 科学探索
        "天文物理": [
            "https://www.nasa.gov/rss/dyn/breaking_news.rss",
            "https://www.space.com/feeds/all",
            "https://www.scientificamerican.com/feed/"
        ],
        "生物医学": [
            "https://www.nature.com/nature.rss",
            "https://www.sciencemag.org/rss/news_current.xml",
            "https://www.cell.com/cell/rss"
        ],
        "环境科学": [
            "https://www.nationalgeographic.com/environment/rss/",
            "https://www.scientificamerican.com/feed/",
            "https://e360.yale.edu/feed"
        ],
        "科普知识": [
            "https://www.scientificamerican.com/feed/",
            "https://www.popsci.com/feed/",
            "https://www.livescience.com/feeds/all"
        ]
    ]
}
