import SwiftUI
import SwiftData

/// 对话视图
struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var behaviorTracker: BehaviorTracker
    @EnvironmentObject var memoryManager: MemoryManager

    @State private var messageText = ""
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    // 添加关闭回调
    @Binding var isShowingChat: Bool

    private var chatService: ChatService {
        let llmService = LLMService(
            apiKey: appState.userConfig.llmApiKey,
            provider: appState.userConfig.llmProvider == "豆包" ? .doubao : .openai,
            model: appState.userConfig.llmModel
        )
        return ChatService(llmService: llmService, modelContext: modelContext)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerView

            Divider()

            // 消息列表
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // 输入框
            inputView
        }
        .background(Color(NSColor.windowBackgroundColor))
        // 移除 onAppear 中的 loadMessages()，每次打开都是空白
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI 对话")
                    .font(.headline)

                // 实时显示播放状态
                if let podcast = audioPlayer.currentPodcast {
                    HStack(spacing: 4) {
                        Image(systemName: audioPlayer.isPlaying ? "play.circle.fill" : "pause.circle.fill")
                            .font(.caption)
                            .foregroundColor(audioPlayer.isPlaying ? .green : .orange)
                        Text(audioPlayer.isPlaying ? "正在收听" : "已暂停")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("·")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(podcast.title)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    Text("通用对话模式")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 清空当前对话按钮
            Button(action: clearCurrentChat) {
                Image(systemName: "trash")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("清空当前对话（历史记录保留）")

            // 关闭按钮
            Button(action: {
                isShowingChat = false
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("关闭对话")
        }
        .padding()
    }

    private var inputView: some View {
        HStack(spacing: 12) {
            TextField("输入消息...", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .disabled(isLoading)
                .onSubmit {
                    // 回车发送消息
                    sendMessage()
                }

            Button(action: sendMessage) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(messageText.isEmpty ? .gray : .accentColor)
                }
            }
            .buttonStyle(.plain)
            .disabled(messageText.isEmpty || isLoading)
        }
        .padding()
    }

    private func loadMessages() {
        messages = chatService.getChatHistory(limit: 50).reversed()
    }

    private func clearCurrentChat() {
        // 只清空当前UI显示，不删除数据库记录
        messages.removeAll()
    }

    private func sendMessage() {
        guard !messageText.isEmpty else { return }

        let userMessage = messageText
        messageText = ""
        isLoading = true
        errorMessage = nil

        // 添加用户消息到界面
        let userMsg = ChatMessage(
            content: userMessage,
            role: "user",
            podcastId: audioPlayer.currentPodcast?.id,
            podcastTitle: audioPlayer.currentPodcast?.title,
            playbackTime: audioPlayer.isPlaying ? audioPlayer.currentTime : nil
        )
        messages.append(userMsg)

        // 创建一个占位的助手消息
        let assistantMsg = ChatMessage(
            content: "",
            role: "assistant",
            podcastId: audioPlayer.currentPodcast?.id,
            podcastTitle: audioPlayer.currentPodcast?.title
        )
        messages.append(assistantMsg)
        let assistantIndex = messages.count - 1

        Task {
            do {
                let response = try await chatService.sendMessageStreaming(
                    userMessage,
                    podcast: audioPlayer.currentPodcast,
                    playbackTime: audioPlayer.isPlaying ? audioPlayer.currentTime : nil,
                    progressHandler: { partialResponse in
                        Task { @MainActor in
                            // 更新助手消息的内容
                            if assistantIndex < messages.count {
                                messages[assistantIndex] = ChatMessage(
                                    content: partialResponse,
                                    role: "assistant",
                                    podcastId: audioPlayer.currentPodcast?.id,
                                    podcastTitle: audioPlayer.currentPodcast?.title
                                )
                            }
                        }
                    }
                )

                await MainActor.run {
                    // 确保最终内容正确
                    if assistantIndex < messages.count {
                        messages[assistantIndex] = ChatMessage(
                            content: response,
                            role: "assistant",
                            podcastId: audioPlayer.currentPodcast?.id,
                            podcastTitle: audioPlayer.currentPodcast?.title
                        )
                    }
                    isLoading = false

                    // 记录聊天行为
                    let extractedTopics = extractTopicsFromMessage(userMessage)
                    behaviorTracker.recordChatMessage(message: userMsg, extractedTopics: extractedTopics)

                    // 每 5 条对话尝试提取用户信息
                    if messages.count % 10 == 0 {
                        Task {
                            do {
                                try await memoryManager.extractFromChat(messages: messages)
                            } catch {
                                print("❌ 从聊天提取信息失败: \(error)")
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    // 移除占位消息
                    if assistantIndex < messages.count {
                        messages.remove(at: assistantIndex)
                    }
                    isLoading = false
                }
            }
        }
    }

    private func clearHistory() {
        messages.removeAll()
        // TODO: 从数据库中删除历史记录
    }

    /// 从消息中提取话题（简单的关键词匹配）
    private func extractTopicsFromMessage(_ message: String) -> [String] {
        var topics: [String] = []

        // 如果当前正在播放播客，添加播客的话题
        if let podcast = audioPlayer.currentPodcast {
            topics.append(contentsOf: podcast.topics)
        }

        // 简单的关键词匹配（可以后续用LLM优化）
        let commonTopics = [
            "Swift", "iOS", "开发", "编程", "技术", "AI", "人工智能",
            "前端", "后端", "数据", "设计", "产品", "创业", "投资"
        ]

        for topic in commonTopics {
            if message.contains(topic) && !topics.contains(topic) {
                topics.append(topic)
            }
        }

        return topics
    }
}

/// 消息气泡
struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == "user" {
                Spacer()
            }

            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(message.role == "user" ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                    .foregroundColor(message.role == "user" ? .white : .primary)
                    .cornerRadius(16)

                HStack(spacing: 4) {
                    if let podcastTitle = message.podcastTitle {
                        Image(systemName: "waveform")
                            .font(.caption2)
                        Text(podcastTitle)
                            .font(.caption2)
                    }

                    if let time = message.formattedPlaybackTime {
                        Text("@ \(time)")
                            .font(.caption2)
                    }

                    Text(message.formattedTimestamp)
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
            .frame(maxWidth: 280, alignment: message.role == "user" ? .trailing : .leading)

            if message.role == "assistant" {
                Spacer()
            }
        }
    }
}
