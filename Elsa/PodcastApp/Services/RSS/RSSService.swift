import Foundation
import FeedKit
import Combine

/// RSS订阅服务
class RSSService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    init() {
        // 禁用系统代理，避免代理连接失败
        let config = URLSessionConfiguration.default
        config.connectionProxyDictionary = [:]
        URLSession.shared.configuration.connectionProxyDictionary = [:]
    }

    /// 获取RSS源内容（不重试）
    func fetchFeed(url: String, retryCount: Int = 0) async throws -> [RSSArticle] {
        guard let feedURL = URL(string: url) else {
            print("❌ RSS源URL无效: \(url)")
            throw RSSError.invalidURL
        }

        print("📡 开始获取RSS: \(url)")

        do {
            let articles = try await fetchFeedOnce(url: feedURL)
            print("✅ RSS获取成功: \(url) - \(articles.count) 篇文章")
            return articles
        } catch {
            print("❌ RSS获取失败: \(url)")
            print("   错误: \(error.localizedDescription)")
            throw error
        }
    }

    /// 单次获取RSS源内容（带超时）
    private func fetchFeedOnce(url: URL) async throws -> [RSSArticle] {
        return try await withThrowingTaskGroup(of: [RSSArticle].self) { group in
            // 添加获取任务
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    let parser = FeedParser(URL: url)

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

            // 添加超时任务
            group.addTask {
                try await Task.sleep(nanoseconds: 10_000_000_000) // 10秒超时
                throw RSSError.networkError("请求超时")
            }

            // 返回第一个完成的任务结果
            if let result = try await group.next() {
                group.cancelAll()
                return result
            }

            throw RSSError.networkError("获取失败")
        }
    }

    /// 从Feed中提取文章
    private func extractArticles(from feed: Feed) -> [RSSArticle] {
        var articles: [RSSArticle] = []

        switch feed {
        case .rss(let rssFeed):
            articles = rssFeed.items?.compactMap { item -> RSSArticle? in
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
            articles = atomFeed.entries?.compactMap { entry -> RSSArticle? in
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
            articles = jsonFeed.items?.compactMap { item -> RSSArticle? in
                guard let title = item.title,
                      let url = item.url else {
                    return nil
                }

                let pubDate = Date() // JSON Feed 的日期处理简化

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
    func fetchMultipleFeeds(urls: [String], progressHandler: ((Int, Int) -> Void)? = nil) async -> [RSSArticle] {
        let totalCount = urls.count
        var completedCount = 0

        return await withTaskGroup(of: (Int, [RSSArticle]).self) { group in
            for (index, url) in urls.enumerated() {
                group.addTask {
                    let articles = (try? await self.fetchFeed(url: url)) ?? []
                    return (index, articles)
                }
            }

            var allArticles: [RSSArticle] = []
            for await (_, articles) in group {
                completedCount += 1
                allArticles.append(contentsOf: articles)

                // 报告进度
                progressHandler?(completedCount, totalCount)
            }

            // 按发布时间排序
            return allArticles.sorted { $0.pubDate > $1.pubDate }
        }
    }

    /// 批量获取多个RSS源（带详细结果）
    func fetchMultipleFeedsWithDetails(urls: [String], progressHandler: ((Int, Int) -> Void)? = nil) async -> [(url: String, articles: [RSSArticle])] {
        let totalCount = urls.count
        var completedCount = 0
        var successCount = 0
        var failedCount = 0

        print("📡 开始批量获取 \(totalCount) 个RSS源...")

        let results = await withTaskGroup(of: (String, [RSSArticle]).self) { group in
            for url in urls {
                group.addTask {
                    do {
                        let articles = try await self.fetchFeed(url: url)
                        return (url, articles)
                    } catch {
                        // 失败时返回空数组，但保留URL信息
                        return (url, [])
                    }
                }
            }

            var results: [(url: String, articles: [RSSArticle])] = []
            for await result in group {
                completedCount += 1
                if result.1.isEmpty {
                    failedCount += 1
                } else {
                    successCount += 1
                }

                results.append(result)

                // 报告进度
                progressHandler?(completedCount, totalCount)
            }

            print("📊 RSS获取完成: 成功 \(successCount)/\(totalCount), 失败 \(failedCount)/\(totalCount)")
            if failedCount > 0 {
                print("⚠️ 失败的RSS源:")
                for result in results where result.1.isEmpty {
                    print("   - \(result.0)")
                }
            }

            return results
        }

        return results
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
