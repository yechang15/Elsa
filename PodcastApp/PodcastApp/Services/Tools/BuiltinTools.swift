import Foundation
import SwiftData

// MARK: - RSSTool

/// 将现有 RSSService 包装为 AgentTool
/// params:
///   - feed_urls: [String]  可选，指定 RSS 源 URL 列表；不传则使用 topics 中的所有 RSS 源
///   - limit: Int           可选，最多返回文章数，默认 10
///   - range: String        可选，"latest" | "today"，默认 "latest"
final class RSSTool: AgentTool, @unchecked Sendable {
    let name = "rss"
    let description = "获取用户订阅的 RSS 源最新文章摘要，作为播客生成的资讯素材"

    private let rssService: RSSService
    /// 外部注入的 RSS 源 URL 列表（来自用户 Topics）
    var feedURLs: [String] = []

    init(rssService: RSSService) {
        self.rssService = rssService
    }

    func execute(params: [String: Any]) async throws -> String {
        let limit = params["limit"] as? Int ?? 10
        let range = params["range"] as? String ?? "latest"

        // 优先使用 params 中指定的 URL，否则用注入的 feedURLs
        let urls: [String]
        if let paramURLs = params["feed_urls"] as? [String], !paramURLs.isEmpty {
            urls = paramURLs
        } else {
            urls = feedURLs
        }

        guard !urls.isEmpty else {
            return "（无可用 RSS 源）"
        }

        let articles = await rssService.fetchMultipleFeeds(urls: urls)

        // range 过滤
        let filtered: [RSSArticle]
        if range == "today" {
            let startOfDay = Calendar.current.startOfDay(for: Date())
            filtered = articles.filter { $0.pubDate >= startOfDay }
        } else {
            filtered = articles
        }

        let limited = Array(filtered.prefix(limit))
        guard !limited.isEmpty else {
            return "（暂无最新文章）"
        }

        let summaries = limited.enumerated().map { idx, article in
            "[\(idx + 1)] \(article.title)\n\(article.description.prefix(200))"
        }
        return summaries.joined(separator: "\n\n")
    }
}

// MARK: - PodcastTool

/// 将 PodcastService 包装为 AgentTool（用于验证链路，P0 阶段主要作为占位）
/// params:
///   - action: String  "generate" | "status"
final class PodcastTool: AgentTool, @unchecked Sendable {
    let name = "podcast"
    let description = "播客生成与状态查询工具"

    private let podcastService: PodcastService

    init(podcastService: PodcastService) {
        self.podcastService = podcastService
    }

    func execute(params: [String: Any]) async throws -> String {
        let action = params["action"] as? String ?? "status"
        switch action {
        case "status":
            let isGenerating = await MainActor.run { podcastService.isGenerating }
            return isGenerating ? "播客正在生成中" : "播客服务就绪"
        default:
            return "播客工具：action=\(action)"
        }
    }
}
