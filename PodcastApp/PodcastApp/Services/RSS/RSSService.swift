import Foundation
import FeedKit
import Combine

/// RSS订阅服务
class RSSService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// 获取RSS源内容
    func fetchFeed(url: String) async throws -> [RSSArticle] {
        guard let feedURL = URL(string: url) else {
            throw RSSError.invalidURL
        }

        return try await withCheckedThrowingContinuation { continuation in
            let parser = FeedParser(URL: feedURL)

            parser.parseAsync { result in
                switch result {
                case .success(let feed):
                    let articles = self.extractArticles(from: feed)
                    continuation.resume(returning: articles)

                case .failure(let error):
                    continuation.resume(throwing: RSSError.parseFailed(error.localizedDescription))
                }
            }
        }
    }

    /// 从Feed中提取文章
    private func extractArticles(from feed: Feed) -> [RSSArticle] {
        var articles: [RSSArticle] = []

        switch feed {
        case .rss(let rssFeed):
            articles = rssFeed.items?.compactMap { item in
                guard let title = item.title,
                      let link = item.link,
                      let pubDate = item.pubDate else {
                    return nil
                }

                return RSSArticle(
                    title: title,
                    link: link,
                    description: item.description ?? "",
                    pubDate: pubDate,
                    content: item.content?.contentEncoded ?? item.description ?? ""
                )
            } ?? []

        case .atom(let atomFeed):
            articles = atomFeed.entries?.compactMap { entry in
                guard let title = entry.title,
                      let link = entry.links?.first?.attributes?.href,
                      let updated = entry.updated else {
                    return nil
                }

                return RSSArticle(
                    title: title,
                    link: link,
                    description: entry.summary?.value ?? "",
                    pubDate: updated,
                    content: entry.content?.value ?? entry.summary?.value ?? ""
                )
            } ?? []

        case .json(let jsonFeed):
            articles = jsonFeed.items?.compactMap { item in
                guard let title = item.title,
                      let url = item.url else {
                    return nil
                }

                let pubDate = item.datePublished.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()

                return RSSArticle(
                    title: title,
                    link: url,
                    description: item.summary ?? "",
                    pubDate: pubDate,
                    content: item.contentHtml ?? item.contentText ?? item.summary ?? ""
                )
            } ?? []
        }

        return articles
    }

    /// 批量获取多个RSS源
    func fetchMultipleFeeds(urls: [String]) async -> [RSSArticle] {
        await withTaskGroup(of: [RSSArticle].self) { group in
            for url in urls {
                group.addTask {
                    (try? await self.fetchFeed(url: url)) ?? []
                }
            }

            var allArticles: [RSSArticle] = []
            for await articles in group {
                allArticles.append(contentsOf: articles)
            }

            // 按发布时间排序
            return allArticles.sorted { $0.pubDate > $1.pubDate }
        }
    }
}

/// RSS文章模型
struct RSSArticle: Identifiable {
    let id = UUID()
    let title: String
    let link: String
    let description: String
    let pubDate: Date
    let content: String

    /// 格式化发布时间
    var formattedPubDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: pubDate, relativeTo: Date())
    }
}

/// RSS错误类型
enum RSSError: LocalizedError {
    case invalidURL
    case parseFailed(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的RSS地址"
        case .parseFailed(let message):
            return "解析失败: \(message)"
        case .networkError(let message):
            return "网络错误: \(message)"
        }
    }
}
