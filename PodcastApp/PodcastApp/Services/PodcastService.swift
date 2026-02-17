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

        let topicNames = topics.map { $0.name }

        // 根据TTS引擎选择不同的生成方式
        if config.ttsEngine == .doubaoPodcast {
            // 使用豆包播客API（一体化模式）
            return try await generateWithDoubaoPodcast(
                articles: articles,
                topics: topicNames,
                config: config,
                modelContext: modelContext
            )
        } else {
            // 使用传统模式（LLM生成脚本 + TTS合成音频）
            return try await generateWithTraditionalTTS(
                articles: articles,
                topics: topicNames,
                config: config,
                modelContext: modelContext
            )
        }
    }

    /// 使用传统TTS生成播客
    private func generateWithTraditionalTTS(
        articles: [RSSArticle],
        topics: [String],
        config: UserConfig,
        modelContext: ModelContext
    ) async throws -> Podcast {
        guard let llmService = llmService else {
            throw PodcastError.llmNotConfigured
        }

        // 2. 生成播客脚本 (60%)
        let script = try await llmService.generatePodcastScript(
            articles: articles,
            topics: topics,
            length: config.defaultLength,
            style: config.hostStyle.rawValue,
            depth: config.contentDepth.rawValue
        )
        generationProgress = 0.6

        // 3. 生成音频 (90%)
        let averageSpeed = Float((config.ttsSpeedA + config.ttsSpeedB) / 2.0)
        let audioURL = try await ttsService.generateAudio(
            script: script,
            voiceA: config.ttsVoiceA,
            voiceB: config.ttsVoiceB,
            speed: averageSpeed
        )
        generationProgress = 0.9

        // 4. 创建播客对象
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

        generationProgress = 1.0

        return podcast
    }

    /// 使用豆包播客API生成播客
    private func generateWithDoubaoPodcast(
        articles: [RSSArticle],
        topics: [String],
        config: UserConfig,
        modelContext: ModelContext
    ) async throws -> Podcast {
        // 验证API Key
        guard !config.doubaoPodcastApiKey.isEmpty else {
            throw PodcastError.generationFailed("豆包播客API Key未配置")
        }

        // 解析API Key (格式: appId:accessToken)
        let components = config.doubaoPodcastApiKey.split(separator: ":")
        guard components.count == 2 else {
            throw PodcastError.generationFailed("豆包播客API Key格式错误，应为: appId:accessToken")
        }

        let appId = String(components[0])
        let accessToken = String(components[1])

        // 2. 准备输入文本 (60%)
        let inputText = prepareInputText(from: articles, topics: topics, config: config)
        generationProgress = 0.6

        // 3. 调用豆包播客API生成音频 (90%)
        let doubaoPodcastService = DoubaoPodcastService(appId: appId, accessToken: accessToken)

        let tempDir = FileManager.default.temporaryDirectory
        let audioFileName = "podcast_\(UUID().uuidString).mp3"
        let audioURL = tempDir.appendingPathComponent(audioFileName)

        try await doubaoPodcastService.generatePodcast(
            inputText: inputText,
            voiceA: config.doubaoPodcastVoiceA,
            voiceB: config.doubaoPodcastVoiceB,
            outputURL: audioURL
        ) { progress in
            print("豆包播客API: \(progress)")
        }

        generationProgress = 0.9

        // 4. 创建播客对象
        let title = generateTitle(from: articles, topics: topics)
        let duration = config.defaultLength * 60

        let podcast = Podcast(
            title: title,
            topics: topics,
            duration: duration,
            scriptContent: inputText,
            length: config.defaultLength,
            contentDepth: config.contentDepth.rawValue,
            hostStyle: config.hostStyle.rawValue
        )

        podcast.audioFilePath = audioURL.path

        modelContext.insert(podcast)
        try modelContext.save()

        generationProgress = 1.0

        return podcast
    }

    /// 准备豆包播客API的输入文本
    private func prepareInputText(from articles: [RSSArticle], topics: [String], config: UserConfig) -> String {
        var text = "# 播客主题\n"
        text += topics.joined(separator: "、") + "\n\n"

        text += "# 内容要求\n"
        text += "- 时长: \(config.defaultLength)分钟\n"
        text += "- 风格: \(config.hostStyle.rawValue)\n"
        text += "- 深度: \(config.contentDepth.rawValue)\n\n"

        text += "# 参考内容\n"
        for (index, article) in articles.prefix(5).enumerated() {
            text += "\(index + 1). \(article.title)\n"
            if let description = article.description {
                text += "   \(description)\n"
            }
            text += "\n"
        }

        return text
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
