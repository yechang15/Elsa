import Foundation
import SwiftData

/// 对话服务 - 处理上下文感知的LLM对话
class ChatService {
    private let llmService: LLMService
    private let modelContext: ModelContext

    init(llmService: LLMService, modelContext: ModelContext) {
        self.llmService = llmService
        self.modelContext = modelContext
    }

    /// 发送消息并获取回复（流式）
    /// - Parameters:
    ///   - message: 用户消息
    ///   - podcast: 当前播放的播客（可选）
    ///   - playbackTime: 当前播放位置（可选）
    ///   - progressHandler: 流式响应处理器
    /// - Returns: AI回复
    func sendMessageStreaming(
        _ message: String,
        podcast: Podcast? = nil,
        playbackTime: Double? = nil,
        progressHandler: ((String) -> Void)?
    ) async throws -> String {
        let startTime = Date()

        // 1. 构建上下文
        let contextStart = Date()
        let context = buildContext(podcast: podcast, playbackTime: playbackTime)
        print("⏱️ 构建上下文耗时: \(Date().timeIntervalSince(contextStart))秒")

        // 2. 构建完整提示词
        let promptStart = Date()
        let prompt = buildPrompt(userMessage: message, context: context)
        print("⏱️ 构建提示词耗时: \(Date().timeIntervalSince(promptStart))秒")
        print("📝 提示词长度: \(prompt.count) 字符")

        // 3. 调用LLM（流式）
        let llmStart = Date()
        let response = try await llmService.chatStreaming(prompt: prompt, progressHandler: progressHandler)
        print("⏱️ LLM调用耗时: \(Date().timeIntervalSince(llmStart))秒")

        // 4. 保存对话历史
        let saveStart = Date()
        await saveMessage(
            userMessage: message,
            assistantMessage: response,
            podcast: podcast,
            playbackTime: playbackTime,
            context: context
        )
        print("⏱️ 保存历史耗时: \(Date().timeIntervalSince(saveStart))秒")

        print("⏱️ 总耗时: \(Date().timeIntervalSince(startTime))秒")

        return response
    }

    /// 发送消息并获取回复
    /// - Parameters:
    ///   - message: 用户消息
    ///   - podcast: 当前播放的播客（可选）
    ///   - playbackTime: 当前播放位置（可选）
    /// - Returns: AI回复
    func sendMessage(
        _ message: String,
        podcast: Podcast? = nil,
        playbackTime: Double? = nil
    ) async throws -> String {
        return try await sendMessageStreaming(message, podcast: podcast, playbackTime: playbackTime, progressHandler: nil)
    }

    /// 构建上下文信息
    private func buildContext(podcast: Podcast?, playbackTime: Double?) -> ChatContext {
        guard let podcast = podcast else {
            return ChatContext(mode: .general)
        }

        // 只获取当前段落，不获取前后段落
        var currentSegment: ScriptSegment?

        if let time = playbackTime {
            print("🔍 查找当前段落 - 播放时间: \(time)秒")
            print("📊 播客总段落数: \(podcast.segments.count)")

            if podcast.segments.isEmpty {
                print("⚠️ 播客没有时间戳数据（可能是旧播客）")
                print("💡 建议：重新生成播客以获得时间戳功能")
            } else {
                currentSegment = podcast.getCurrentSegment(at: time)

                if let segment = currentSegment {
                    print("✅ 找到当前段落: \(segment.speaker) - [\(segment.startTime)s - \(segment.endTime)s]")
                    print("📝 内容: \(segment.content.prefix(50))...")
                } else {
                    print("❌ 未找到当前段落！")
                    // 打印所有段落的时间范围，帮助调试
                    for (index, seg) in podcast.segments.prefix(5).enumerated() {
                        print("  段落\(index): [\(seg.startTime)s - \(seg.endTime)s]")
                    }
                }
            }
        } else {
            print("⚠️ 没有播放时间信息")
        }

        return ChatContext(
            mode: .podcast,
            podcastTitle: podcast.title,
            podcastTopics: podcast.topics,
            currentSegment: currentSegment,
            contextSegments: nil,
            playbackTime: playbackTime,
            sourceArticles: podcast.sourceArticles.prefix(5).map { $0 }
        )
    }

    /// 构建提示词
    private func buildPrompt(userMessage: String, context: ChatContext) -> String {
        switch context.mode {
        case .general:
            return """
            你是一个友好的AI助手，可以回答用户的各种问题。

            用户问题：\(userMessage)
            """

        case .podcast:
            // 检查是否有当前段落
            guard let segment = context.currentSegment else {
                // 如果没有当前段落，提供播客的基本信息
                var prompt = """
                你是一个播客助手。用户正在收听播客，但当前无法定位到具体的播放段落。

                播客信息：
                - 标题：\(context.podcastTitle ?? "未知")
                - 话题：\(context.podcastTopics?.joined(separator: "、") ?? "未知")
                """

                if let articles = context.sourceArticles, !articles.isEmpty {
                    prompt += "\n\n播客的来源文章："
                    for (index, article) in articles.enumerated() {
                        prompt += "\n\(index + 1). \(article.title)"
                    }
                }

                prompt += """

                用户问题：\(userMessage)

                请基于播客的整体信息回答用户的问题。如果需要具体的播放内容，请提示用户确保播客正在播放。
                """

                return prompt
            }

            // 有当前段落的情况
            var prompt = """
            你是一个播客助手，正在帮助用户理解播客内容。

            重要：用户正在收听播客，当前播放到某个具体的段落。用户的问题是关于【当前这个段落】的，不是关于整个播客的。

            【当前段落内容】
            \(segment.speaker)：\(segment.content)
            """

            // 如果有来源文章索引，精准显示对应的文章
            if let indices = segment.sourceArticleIndices,
               let articles = context.sourceArticles,
               !indices.isEmpty {
                prompt += "\n\n【这段内容的来源】"
                for index in indices {
                    if index < articles.count {
                        let article = articles[index]
                        prompt += "\n• \(article.title)"
                        prompt += "\n  \(article.description.prefix(200))..."
                        prompt += "\n  链接：\(article.link)"
                    }
                }
            } else if let articles = context.sourceArticles, !articles.isEmpty {
                // 如果没有精确的来源索引，显示所有来源文章（但提示可能不是全部相关）
                prompt += "\n\n【播客的来源文章】（注意：当前段落可能只涉及其中部分文章）"
                for (index, article) in articles.enumerated() {
                    prompt += "\n\(index + 1). \(article.title)"
                    prompt += "\n   \(article.description.prefix(100))..."
                }
            }

            prompt += """

            用户问题：\(userMessage)

            回答要求：
            1. 【重要】只回答关于【当前段落内容】的问题，不要总结整个播客
            2. 如果用户说"详细聊聊"或"展开讲讲"，只针对当前段落的内容进行深入解释
            3. 如果当前段落有明确的来源文章，优先基于来源文章提供更多信息
            4. 回答要聚焦、具体，不要泛泛而谈
            5. 如果当前段落内容不足以回答问题，可以说明需要更多上下文
            """

            return prompt
        }
    }

    /// 调用LLM
    private func callLLM(prompt: String) async throws -> String {
        return try await llmService.chat(prompt: prompt)
    }

    /// 保存对话历史
    private func saveMessage(
        userMessage: String,
        assistantMessage: String,
        podcast: Podcast?,
        playbackTime: Double?,
        context: ChatContext
    ) async {
        let podcastId = podcast?.id
        let podcastTitle = podcast?.title
        await MainActor.run {
            // 保存用户消息
            let userMsg = ChatMessage(
                content: userMessage,
                role: "user",
                podcastId: podcastId,
                podcastTitle: podcastTitle,
                playbackTime: playbackTime,
                contextSegments: context.contextSegments
            )
            modelContext.insert(userMsg)

            // 保存助手回复
            let assistantMsg = ChatMessage(
                content: assistantMessage,
                role: "assistant",
                podcastId: podcastId,
                podcastTitle: podcastTitle,
                playbackTime: playbackTime
            )
            modelContext.insert(assistantMsg)

            try? modelContext.save()
        }
    }

    /// 获取对话历史
    func getChatHistory(limit: Int = 50) -> [ChatMessage] {
        let descriptor = FetchDescriptor<ChatMessage>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// 获取与特定播客相关的对话历史
    func getChatHistory(for podcastId: UUID, limit: Int = 20) -> [ChatMessage] {
        let descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.podcastId == podcastId },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}

/// 对话上下文
struct ChatContext {
    enum Mode {
        case general // 通用对话
        case podcast // 播客相关对话
    }

    let mode: Mode
    var podcastTitle: String?
    var podcastTopics: [String]?
    var currentSegment: ScriptSegment?
    var contextSegments: [ScriptSegment]?
    var playbackTime: Double?
    var sourceArticles: [SourceArticle]?
}
