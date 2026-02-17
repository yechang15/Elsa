import Foundation
import SwiftData

/// 播客生成服务
class PodcastService: ObservableObject {
    @Published var isGenerating = false
    @Published var generationProgress: Double = 0
    @Published var errorMessage: String?

    private let rssService = RSSService()
    private var llmService: LLMService?
    private let ttsService = TTSService()

    /// 初始化LLM服务
    func setupLLM(apiKey: String, provider: LLMProvider, model: String) {
        llmService = LLMService(apiKey: apiKey, provider: provider, model: model)
    }

    /// 生成播客
    func generatePodcast(
        topics: [Topic],
        config: UserConfig,
        modelContext: ModelContext
    ) async throws -> Podcast {
        guard let llmService = llmService else {
            throw PodcastError.llmNotConfigured
        }

        isGenerating = true
        generationProgress = 0

        defer {
            isGenerating = false
            generationProgress = 0
        }

        // 1. 获取RSS内容 (30%)
        generationProgress = 0.1
        let rssFeeds = topics.flatMap { $0.rssFeeds }
        let feedURLs = rssFeeds.map { $0.url }

        let articles = await rssService.fetchMultipleFeeds(urls: feedURLs)
        generationProgress = 0.3

        guard !articles.isEmpty else {
            throw PodcastError.noContent
        }

        // 2. 生成播客脚本 (60%)
        let topicNames = topics.map { $0.name }
        let script = try await llmService.generatePodcastScript(
            articles: articles,
            topics: topicNames,
            length: config.defaultLength,
            style: config.hostStyle.rawValue,
            depth: config.contentDepth.rawValue
        )
        generationProgress = 0.6

        // 3. 生成音频 (90%)
        // 使用两个主播的平均语速
        let averageSpeed = Float((config.ttsSpeedA + config.ttsSpeedB) / 2.0)
        let audioURL = try await ttsService.generateAudio(
            script: script,
            voiceA: config.ttsVoiceA,
            voiceB: config.ttsVoiceB,
            speed: averageSpeed
        )
        generationProgress = 0.9

        // 4. 创建播客对象
        let title = generateTitle(from: articles, topics: topicNames)
        let duration = config.defaultLength * 60 // 转换为秒

        let podcast = Podcast(
            title: title,
            topics: topicNames,
            duration: duration,
            scriptContent: script,
            length: config.defaultLength,
            contentDepth: config.contentDepth.rawValue,
            hostStyle: config.hostStyle.rawValue
        )

        // 保存音频文件路径
        podcast.audioFilePath = audioURL.path

        // 保存到数据库
        modelContext.insert(podcast)
        try modelContext.save()

        generationProgress = 1.0

        return podcast
    }

    /// 生成播客标题
    private func generateTitle(from articles: [RSSArticle], topics: [String]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())

        if topics.count == 1 {
            return "\(topics[0]) - \(dateString)"
        } else {
            return "\(topics.joined(separator: " · ")) - \(dateString)"
        }
    }

    /// 手动生成播客（基于选定的文章）
    func generatePodcastFromArticles(
        articles: [RSSArticle],
        topics: [String],
        config: UserConfig,
        modelContext: ModelContext
    ) async throws -> Podcast {
        guard let llmService = llmService else {
            throw PodcastError.llmNotConfigured
        }

        isGenerating = true
        defer { isGenerating = false }

        // 生成脚本
        let script = try await llmService.generatePodcastScript(
            articles: articles,
            topics: topics,
            length: config.defaultLength,
            style: config.hostStyle.rawValue,
            depth: config.contentDepth.rawValue
        )

        // 生成音频
        let averageSpeed = Float((config.ttsSpeedA + config.ttsSpeedB) / 2.0)
        let audioURL = try await ttsService.generateAudio(
            script: script,
            voiceA: config.ttsVoiceA,
            voiceB: config.ttsVoiceB,
            speed: averageSpeed
        )

        // 创建播客
        let title = generateTitle(from: articles, topics: topics)
        let duration = config.defaultLength * 60

        let podcast = Podcast(
            title: title,
            topics: topics,
            duration: duration,
            scriptContent: script,
            length: config.defaultLength,
            contentDepth: config.contentDepth.rawValue,
            hostStyle: config.hostStyle.rawValue
        )

        podcast.audioFilePath = audioURL.path

        modelContext.insert(podcast)
        try modelContext.save()

        return podcast
    }
}

/// 播客生成错误
enum PodcastError: LocalizedError {
    case llmNotConfigured
    case noContent
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .llmNotConfigured:
            return "LLM未配置，请先在设置中配置API Key"
        case .noContent:
            return "没有可用的RSS内容"
        case .generationFailed(let message):
            return "生成失败: \(message)"
        }
    }
}
