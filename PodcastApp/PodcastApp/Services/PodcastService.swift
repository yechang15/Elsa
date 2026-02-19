import Foundation
import SwiftData

/// 播客生成服务
class PodcastService: ObservableObject {
    @Published var isGenerating = false
    @Published var generationProgress: Double = 0
    @Published var errorMessage: String?
    @Published var currentStatus: String = "" // 新增：当前状态描述

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
        modelContext: ModelContext,
        category: String = "系统推荐"
    ) async throws -> Podcast {
        await MainActor.run {
            isGenerating = true
            generationProgress = 0
        }

        defer {
            Task { @MainActor in
                isGenerating = false
                generationProgress = 0
            }
        }

        // 1. 获取RSS内容 (30%)
        await MainActor.run {
            generationProgress = 0.1
            currentStatus = "正在获取RSS内容..."
        }
        let rssFeeds = topics.flatMap { $0.rssFeeds }

        // 去重：使用 Set 来确保每个 URL 只获取一次
        let uniqueURLs = Array(Set(rssFeeds.map { $0.url }))

        print("📊 总共 \(rssFeeds.count) 个RSS源，去重后 \(uniqueURLs.count) 个")

        // 使用带详细结果的方法获取RSS内容
        let feedResults = await rssService.fetchMultipleFeedsWithDetails(urls: uniqueURLs) { completed, total in
            Task { @MainActor in
                self.currentStatus = "正在获取RSS内容... (\(completed)/\(total))"
                // 进度从0.1到0.3，根据完成比例计算
                self.generationProgress = 0.1 + (0.2 * Double(completed) / Double(total))
            }
        }

        // 合并所有文章
        let articles = feedResults.flatMap { $0.articles }.sorted { $0.pubDate > $1.pubDate }

        // 更新RSS源的元数据
        await MainActor.run {
            let now = Date()
            for feed in rssFeeds {
                feed.lastUpdated = now
                // 查找该feed的文章数
                if let result = feedResults.first(where: { $0.url == feed.url }) {
                    feed.articleCount = result.articles.count
                }
            }
            try? modelContext.save()
        }

        await MainActor.run {
            generationProgress = 0.3
            currentStatus = "已获取 \(articles.count) 篇文章"
        }

        guard !articles.isEmpty else {
            throw PodcastError.noContent
        }

        let topicNames = topics.map { $0.name }

        // 根据TTS引擎的策略选择不同的生成方式
        // 策略1：一体化引擎（如豆包播客API）- 直接将原文发送给API，由API内部完成脚本生成和音频合成
        // 策略2：纯TTS引擎（如系统TTS、豆包TTS、OpenAI TTS等）- 先用LLM生成对话脚本，再用TTS合成音频
        if config.ttsEngine.needsScriptGeneration {
            // 策略2：纯TTS引擎 - 需要LLM生成脚本
            return try await generateWithTraditionalTTS(
                articles: articles,
                topics: topicNames,
                config: config,
                modelContext: modelContext,
                category: category
            )
        } else {
            // 策略1：一体化引擎 - 不需要LLM生成脚本
            switch config.ttsEngine {
            case .doubaoPodcast:
                return try await generateWithDoubaoPodcast(
                    articles: articles,
                    topics: topicNames,
                    config: config,
                    modelContext: modelContext,
                    category: category
                )
            default:
                throw PodcastError.generationFailed("不支持的一体化引擎: \(config.ttsEngine.rawValue)")
            }
        }
    }

    /// 使用传统TTS生成播客（策略2：纯TTS引擎）
    /// 流程：原文 → LLM生成对话脚本 → TTS合成音频
    /// 适用引擎：系统TTS、豆包TTS、OpenAI TTS、ElevenLabs等
    private func generateWithTraditionalTTS(
        articles: [RSSArticle],
        topics: [String],
        config: UserConfig,
        modelContext: ModelContext,
        category: String
    ) async throws -> Podcast {
        // 验证：纯TTS引擎必须配置LLM服务
        guard let llmService = llmService else {
            throw PodcastError.llmNotConfigured
        }

        // 2. 生成播客脚本 (60%)
        await MainActor.run { currentStatus = "正在生成播客脚本..." }

        // 获取主播名称
        let (hostAName, hostBName) = getHostNames(from: config)

        // 确定播客类型和频率
        let podcastType: PodcastType = (category == "系统推荐") ? .systemRecommended : .topicSpecific
        let frequency = getFrequencyDescription(category: category, config: config)

        let script = try await llmService.generatePodcastScript(
            articles: articles,
            topics: topics,
            length: config.defaultLength,
            style: config.hostStyle.rawValue,
            depth: config.contentDepth.rawValue,
            hostAName: hostAName,
            hostBName: hostBName,
            podcastType: podcastType,
            frequency: frequency
        ) { progress in
            // 实时显示脚本生成进度
            Task { @MainActor in
                self.currentStatus = progress
            }
        }
        await MainActor.run {
            generationProgress = 0.6
            currentStatus = "脚本生成完成，共 \(script.count) 字符"
        }

        // 3. 生成音频 (90%)
        await MainActor.run { currentStatus = "正在合成音频..." }
        let averageSpeed = Float((config.ttsSpeedA + config.ttsSpeedB) / 2.0)

        // 根据 TTS 引擎选择 API Key 和音色
        let ttsApiKey: String
        let voiceA: String
        let voiceB: String

        switch config.ttsEngine {
        case .doubaoTTS:
            ttsApiKey = config.llmApiKey // 使用 LLM API Key（豆包统一）
            voiceA = config.doubaoTTSVoiceA
            voiceB = config.doubaoTTSVoiceB
        case .openai:
            ttsApiKey = config.openaiTTSApiKey
            voiceA = config.openaiTTSVoiceA
            voiceB = config.openaiTTSVoiceB
        case .elevenlabs:
            ttsApiKey = config.elevenlabsApiKey
            voiceA = config.elevenlabsVoiceA
            voiceB = config.elevenlabsVoiceB
        default:
            ttsApiKey = ""
            voiceA = config.ttsVoiceA
            voiceB = config.ttsVoiceB
        }

        let (audioURL, segments) = try await ttsService.generateAudio(
            script: script,
            voiceA: voiceA,
            voiceB: voiceB,
            speed: averageSpeed,
            engine: config.ttsEngine,
            apiKey: ttsApiKey,
            appId: config.doubaoTTSApiKey,
            accessToken: config.doubaoTTSAccessToken,
            resourceId: config.doubaoTTSResourceId
        )
        await MainActor.run { generationProgress = 0.9 }

        // 4. 创建播客对象
        let title = generateTitle(from: articles, topics: topics)
        let duration = config.defaultLength * 60

        // 转换 RSS 文章为 SourceArticle
        let sourceArticles = articles.prefix(10).map { article in
            SourceArticle(
                title: article.title,
                link: article.link,
                description: article.description,
                pubDate: article.pubDate
            )
        }

        let podcast = Podcast(
            title: title,
            topics: topics,
            duration: duration,
            scriptContent: script,
            length: config.defaultLength,
            contentDepth: config.contentDepth.rawValue,
            hostStyle: config.hostStyle.rawValue,
            category: category,
            sourceArticles: sourceArticles,
            segments: segments
        )

        podcast.audioFilePath = audioURL.path

        await MainActor.run {
            modelContext.insert(podcast)
            try? modelContext.save()
            generationProgress = 1.0
        }

        return podcast
    }

    /// 使用豆包播客API生成播客（策略1：一体化引擎）
    /// 流程：原文 → 一体化API（内部生成脚本+合成音频）
    /// 特点：不需要单独配置LLM，API内部完成所有处理
    private func generateWithDoubaoPodcast(
        articles: [RSSArticle],
        topics: [String],
        config: UserConfig,
        modelContext: ModelContext,
        category: String
    ) async throws -> Podcast {
        // 验证配置
        guard !config.doubaoPodcastAppId.isEmpty && !config.doubaoPodcastAccessToken.isEmpty else {
            throw PodcastError.generationFailed("豆包播客API配置不完整")
        }

        let appId = config.doubaoPodcastAppId
        let accessToken = config.doubaoPodcastAccessToken

        // 2. 准备输入文本 (60%)
        let inputText = prepareInputText(from: articles, topics: topics, config: config)
        await MainActor.run { generationProgress = 0.6 }

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

        await MainActor.run { generationProgress = 0.9 }

        // 4. 创建播客对象
        let title = generateTitle(from: articles, topics: topics)
        let duration = config.defaultLength * 60

        // 转换 RSS 文章为 SourceArticle
        let sourceArticles = articles.prefix(10).map { article in
            SourceArticle(
                title: article.title,
                link: article.link,
                description: article.description,
                pubDate: article.pubDate
            )
        }

        let podcast = Podcast(
            title: title,
            topics: topics,
            duration: duration,
            scriptContent: inputText,
            length: config.defaultLength,
            contentDepth: config.contentDepth.rawValue,
            hostStyle: config.hostStyle.rawValue,
            category: category,
            sourceArticles: sourceArticles
        )

        podcast.audioFilePath = audioURL.path

        await MainActor.run {
            modelContext.insert(podcast)
            try? modelContext.save()
            generationProgress = 1.0
        }

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
            if !article.description.isEmpty {
                text += "   \(article.description)\n"
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

    /// 从配置中获取主播名称
    /// 从音色ID或名称中提取简短的主播名称
    private func getHostNames(from config: UserConfig) -> (String, String) {
        let hostAName: String
        let hostBName: String

        switch config.ttsEngine {
        case .doubaoTTS:
            // 从豆包TTS音色ID中提取名称
            hostAName = extractVoiceName(from: config.doubaoTTSVoiceA, resourceId: config.doubaoTTSResourceId)
            hostBName = extractVoiceName(from: config.doubaoTTSVoiceB, resourceId: config.doubaoTTSResourceId)
        case .doubaoPodcast:
            // 从豆包播客音色ID中提取名称
            hostAName = extractVoiceName(from: config.doubaoPodcastVoiceA, resourceId: "")
            hostBName = extractVoiceName(from: config.doubaoPodcastVoiceB, resourceId: "")
        case .system:
            // 系统TTS使用默认名称
            hostAName = "婷婷"
            hostBName = "辛吉"
        case .openai:
            // OpenAI TTS使用音色名称
            hostAName = config.openaiTTSVoiceA.capitalized
            hostBName = config.openaiTTSVoiceB.capitalized
        case .elevenlabs:
            // ElevenLabs使用默认名称
            hostAName = "主播A"
            hostBName = "主播B"
        }

        return (hostAName, hostBName)
    }

    /// 从音色ID中提取名称
    private func extractVoiceName(from voiceId: String, resourceId: String) -> String {
        // 尝试从VolcengineVoices中查找
        let allVoices = VolcengineVoices.tts2Voices + VolcengineVoices.tts1Voices
        if let voice = allVoices.first(where: { $0.id == voiceId }) {
            // 提取名称的第一部分（去掉版本号和描述）
            let name = voice.name
            // 例如："小何 2.0" -> "小何", "Vivi 2.0" -> "Vivi"
            if let firstPart = name.components(separatedBy: " ").first {
                return firstPart
            }
            return name
        }

        // 如果找不到，返回默认名称
        return "主播"
    }

    /// 获取频率描述
    private func getFrequencyDescription(category: String, config: UserConfig) -> String {
        if category == "系统推荐" {
            // 系统推荐播客的频率
            switch config.autoGenerateFrequency {
            case .daily:
                return "每天"
            case .weekdays:
                return "每个工作日"
            case .weekends:
                return "每个周末"
            case .custom:
                return "定期"
            }
        } else {
            // 话题专属播客的频率
            let interval = config.topicGenerateInterval
            if interval == 1 {
                return "每小时"
            } else if interval < 24 {
                return "每\(interval)小时"
            } else {
                let days = interval / 24
                return "每\(days)天"
            }
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

        await MainActor.run { isGenerating = true }
        defer {
            Task { @MainActor in
                isGenerating = false
            }
        }

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
        let (audioURL, segments) = try await ttsService.generateAudio(
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
            hostStyle: config.hostStyle.rawValue,
            segments: segments
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
