import Foundation
import SwiftData

/// 记忆文件类型
enum MemoryFileType: String {
    case profile = "profile.md"
    case preferences = "preferences.md"
    case goals = "goals.md"
    case summary = "memory_summary.md"
}

/// 用户记忆管理服务
@MainActor
class MemoryManager: ObservableObject {
    private let modelContext: ModelContext
    private let fileManager = FileManager.default
    private let memoryDirectory: URL

    // 行为追踪器引用
    private weak var behaviorTracker: BehaviorTracker?

    // LLM 服务引用（用于生成摘要）
    var llmService: LLMService?

    @Published var lastUpdateDate: Date?

    init(modelContext: ModelContext, behaviorTracker: BehaviorTracker? = nil) {
        self.modelContext = modelContext
        self.behaviorTracker = behaviorTracker

        // 创建 memory 目录
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.memoryDirectory = documentsPath.appendingPathComponent("memory")

        // 确保目录存在
        try? fileManager.createDirectory(at: memoryDirectory, withIntermediateDirectories: true)

        print("📁 Memory 目录: \(memoryDirectory.path)")
    }

    // MARK: - 文件读取

    /// 读取指定类型的记忆文件
    func loadMemory(_ type: MemoryFileType) -> String? {
        let fileURL = memoryDirectory.appendingPathComponent(type.rawValue)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            print("⚠️ 记忆文件不存在: \(type.rawValue)")
            return nil
        }

        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            print("✅ 读取记忆文件: \(type.rawValue) (\(content.count) 字符)")
            return content
        } catch {
            print("❌ 读取记忆文件失败: \(error)")
            return nil
        }
    }

    /// 读取摘要（优先使用）
    func loadSummary() -> String {
        if let summary = loadMemory(.summary) {
            return summary
        }

        // 如果摘要不存在，尝试生成
        print("⚠️ 摘要不存在，返回默认提示")
        return "# 用户记忆摘要\n\n暂无用户记忆数据。这是新用户，请根据用户的话题选择生成通用内容。"
    }

    /// 读取偏好设置
    func loadPreferences() -> String {
        if let preferences = loadMemory(.preferences) {
            return preferences
        }

        print("⚠️ 偏好设置不存在，返回默认提示")
        return "# 播客偏好\n\n暂无偏好数据。"
    }

    /// 读取用户画像
    func loadProfile() -> String? {
        return loadMemory(.profile)
    }

    /// 读取目标
    func loadGoals() -> String? {
        return loadMemory(.goals)
    }

    // MARK: - 文件写入

    /// 保存记忆文件
    func saveMemory(_ type: MemoryFileType, content: String) throws {
        let fileURL = memoryDirectory.appendingPathComponent(type.rawValue)

        // 检查文件大小，如果超过 800 字，尝试压缩
        if content.count > 800, let llmService = llmService {
            print("⚠️ 记忆文件超过 800 字，尝试压缩...")
            Task {
                do {
                    let compressed = try await compressMemory(content: content, type: type, llmService: llmService)
                    try compressed.write(to: fileURL, atomically: true, encoding: .utf8)
                    lastUpdateDate = Date()
                    print("✅ 压缩后保存记忆文件: \(type.rawValue) (\(compressed.count) 字符)")
                } catch {
                    print("❌ 压缩失败，保存原文件: \(error)")
                    try content.write(to: fileURL, atomically: true, encoding: .utf8)
                    lastUpdateDate = Date()
                }
            }
        } else {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            lastUpdateDate = Date()
            print("✅ 保存记忆文件: \(type.rawValue) (\(content.count) 字符)")
        }
    }

    /// 更新偏好设置
    func updatePreferences(_ content: String) throws {
        try saveMemory(.preferences, content: content)
    }

    /// 更新用户画像
    func updateProfile(_ content: String) throws {
        try saveMemory(.profile, content: content)
    }

    /// 更新目标
    func updateGoals(_ content: String) throws {
        try saveMemory(.goals, content: content)
    }

    /// 更新摘要
    func updateSummary(_ content: String) throws {
        try saveMemory(.summary, content: content)
    }

    // MARK: - 智能更新（基于行为数据）

    /// 从行为数据生成偏好设置
    func generatePreferencesFromBehavior() async throws -> String {
        guard let tracker = behaviorTracker else {
            throw MemoryError.behaviorTrackerNotAvailable
        }

        // 获取用户订阅的话题
        let subscribedTopics = getSubscribedTopics()

        // 获取话题偏好数据（从播放行为分析）
        let topicPreferences = getTopicPreferences()

        // 获取播放会话数据
        let recentSessions = tracker.getRecentPlaybackSessions(limit: 20)

        // 构建偏好内容
        var content = "# Podcast Preferences\n\n"
        content += "最后更新：\(Date().formatted(date: .long, time: .omitted))\n\n"

        // 1. 用户订阅的话题（主动选择）
        content += "## Subscribed Topics (订阅话题)\n\n"
        if !subscribedTopics.isEmpty {
            content += "用户主动订阅的话题（按优先级排序）：\n\n"
            for topic in subscribedTopics.sorted(by: { $0.priority < $1.priority }) {
                content += "- \(topic.name)\n"
            }
            content += "\n"
        } else {
            content += "暂无订阅话题。\n\n"
        }

        // 2. 从播放行为分析出的话题偏好
        content += "## Topic Preferences from Behavior (播放行为分析)\n\n"
        if !topicPreferences.isEmpty {
            let highInterest = topicPreferences.filter { $0.preferenceScore >= 80 }
            let mediumInterest = topicPreferences.filter { $0.preferenceScore >= 60 && $0.preferenceScore < 80 }
            let lowInterest = topicPreferences.filter { $0.preferenceScore < 40 }

            if !highInterest.isEmpty {
                content += "### 强烈感兴趣 (80-100分)\n"
                for pref in highInterest.sorted(by: { $0.preferenceScore > $1.preferenceScore }) {
                    content += "- \(pref.topicName) (\(Int(pref.preferenceScore))分) - 完播率: \(Int(pref.averageCompletionRate * 100))%\n"
                }
                content += "\n"
            }

            if !mediumInterest.isEmpty {
                content += "### 比较感兴趣 (60-80分)\n"
                for pref in mediumInterest.sorted(by: { $0.preferenceScore > $1.preferenceScore }) {
                    content += "- \(pref.topicName) (\(Int(pref.preferenceScore))分) - 完播率: \(Int(pref.averageCompletionRate * 100))%\n"
                }
                content += "\n"
            }

            if !lowInterest.isEmpty {
                content += "### 不感兴趣 (0-40分)\n"
                for pref in lowInterest.sorted(by: { $0.preferenceScore > $1.preferenceScore }) {
                    content += "- \(pref.topicName) (\(Int(pref.preferenceScore))分) - 完播率: \(Int(pref.averageCompletionRate * 100))%\n"
                }
                content += "\n"
            }
        } else {
            content += "暂无播放数据，无法分析话题偏好。请先播放一些播客。\n\n"
        }

        // 3. 时长偏好（基于完播率）
        content += "## Length Preferences (时长偏好)\n\n"
        let avgCompletionRate = recentSessions.isEmpty ? 0 : recentSessions.map { $0.completionRate }.reduce(0, +) / Double(recentSessions.count)
        let avgDuration = recentSessions.isEmpty ? 0 : recentSessions.map { $0.totalDuration }.reduce(0, +) / recentSessions.count

        if avgDuration > 0 {
            content += "- 平均播放时长：\(avgDuration / 60) 分钟\n"
            content += "- 平均完播率：\(Int(avgCompletionRate * 100))%\n\n"
        } else {
            content += "暂无播放数据。\n\n"
        }

        // 4. 播放速度偏好
        content += "## Pacing Preferences (节奏偏好)\n\n"
        let avgSpeed = recentSessions.isEmpty ? 1.0 : recentSessions.map { $0.playbackSpeed }.reduce(0, +) / Double(recentSessions.count)
        if avgSpeed > 1.0 {
            content += "- 经常使用 \(String(format: "%.1f", avgSpeed))x 播放速度\n"
            content += "- 偏好紧凑的节奏，信息密度高\n\n"
        } else if !recentSessions.isEmpty {
            content += "- 使用正常播放速度\n\n"
        } else {
            content += "暂无播放数据。\n\n"
        }

        return content
    }

    /// 生成记忆摘要（从其他 3 个 MD 文件压缩）
    func generateSummary() async throws -> String {
        guard let llmService = llmService else {
            throw MemoryError.llmServiceNotAvailable
        }

        // 读取其他 3 个记忆文件
        let preferences = loadPreferences()
        let profile = loadProfile()
        let goals = loadGoals()

        // 使用 LLM 智能压缩
        return try await generateSummaryWithLLM(
            preferences: preferences,
            profile: profile,
            goals: goals,
            llmService: llmService
        )
    }

    /// 使用 LLM 生成智能摘要
    private func generateSummaryWithLLM(
        preferences: String,
        profile: String?,
        goals: String?,
        llmService: LLMService
    ) async throws -> String {
        print("🤖 使用 LLM 生成记忆摘要...")

        let prompt = """
        你是一个用户画像分析助手。请将以下用户记忆信息压缩为一个简洁的摘要（300字以内）。

        **重点保留**：
        1. 用户的核心兴趣话题（从偏好中提取高分话题）
        2. 内容偏好（时长、风格、深度、节奏）
        3. 当前目标和学习方向
        4. 明确不喜欢的内容类型

        **输出格式**：
        ```markdown
        # User Memory Summary

        ## 一句话画像
        [用一句话概括用户特征，包含职业背景、兴趣方向、内容偏好]

        ## 核心特征
        - **职业背景**：[如果有]
        - **当前目标**：[如果有]
        - **内容偏好**：[列出3-5个高分话题]
        - **形式偏好**：[时长、对话形式、播放速度等]
        - **风格偏好**：[理性/感性、数据驱动/故事驱动等]
        - **明确排斥**：[不喜欢的内容类型]

        ## 生成建议
        - 话题选择：[具体建议]
        - 内容深度：[具体建议]
        - 对话风格：[具体建议]
        - 时长控制：[具体建议]
        - 节奏：[具体建议]

        最后更新：\(Date().formatted(date: .long, time: .omitted))
        ```

        ---

        【用户画像】
        \(profile ?? "暂无用户画像数据")

        【播客偏好】
        \(preferences)

        【当前目标】
        \(goals ?? "暂无目标数据")

        ---

        请严格按照上述格式输出摘要，不要添加其他说明文字。如果某个字段没有数据，可以省略该字段。
        """

        // 调用 LLM 生成摘要
        let summary = try await llmService.generateText(prompt: prompt)

        print("✅ LLM 摘要生成完成")
        return summary
    }

    // MARK: - 辅助方法

    /// 获取所有话题偏好
    private func getTopicPreferences() -> [TopicPreference] {
        let descriptor = FetchDescriptor<TopicPreference>(
            sortBy: [SortDescriptor(\TopicPreference.preferenceScore, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// 获取用户订阅的话题
    private func getSubscribedTopics() -> [Topic] {
        let descriptor = FetchDescriptor<Topic>(
            sortBy: [SortDescriptor(\Topic.priority, order: .forward)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// 检查是否需要更新记忆
    func shouldUpdateMemory() -> Bool {
        guard let tracker = behaviorTracker else { return false }

        // 获取最近的播放会话数
        let recentSessions = tracker.getRecentPlaybackSessions(limit: 100)

        // 如果没有记忆文件，且有足够的数据，应该更新
        if loadMemory(.summary) == nil && recentSessions.count >= 5 {
            return true
        }

        // 如果距离上次更新超过一定时间，且有新数据
        if let lastUpdate = lastUpdateDate {
            let daysSinceUpdate = Date().timeIntervalSince(lastUpdate) / 86400
            if daysSinceUpdate >= 7 && recentSessions.count >= 10 {
                return true
            }
        }

        return false
    }

    /// 完整更新记忆（生成所有文件）
    func updateMemoryFromBehavior() async throws {
        print("🔄 开始更新记忆...")

        // 1. 生成偏好设置
        let preferences = try await generatePreferencesFromBehavior()
        try updatePreferences(preferences)

        // 2. 生成摘要
        let summary = try await generateSummary()
        try updateSummary(summary)

        print("✅ 记忆更新完成")
    }

    // MARK: - 从聊天提取信息

    /// 从聊天消息中提取用户画像和目标
    func extractFromChat(messages: [ChatMessage]) async throws {
        guard let llmService = llmService else {
            print("⚠️ 无 LLM 服务，跳过聊天提取")
            return
        }

        // 只分析最近的 20 条消息
        let recentMessages = messages.suffix(20)
        guard !recentMessages.isEmpty else { return }

        // 构建对话历史
        let conversationText = recentMessages.map { message in
            let role = message.role == "user" ? "用户" : "助手"
            return "\(role): \(message.content)"
        }.joined(separator: "\n\n")

        let prompt = """
        请分析以下对话，提取用户的长期特征信息。

        **提取内容**：
        1. **用户画像**（profile）：职业背景、教育背景、年龄段、性格特征、沟通风格等长期稳定信息
        2. **当前目标**（goals）：学习目标、职业目标、短期需求、生活阶段等动态信息

        **输出格式**：
        ```json
        {
          "hasProfileInfo": true/false,
          "profile": "用户画像的 Markdown 内容（如果有）",
          "hasGoalsInfo": true/false,
          "goals": "当前目标的 Markdown 内容（如果有）"
        }
        ```

        **注意**：
        - 只提取明确表达的长期特征，不要推测
        - 如果对话中没有相关信息，设置 hasProfileInfo/hasGoalsInfo 为 false
        - 使用 Markdown 格式，参考以下结构：

        **Profile 格式**：
        ```markdown
        # User Profile

        ## Background
        - 职业：...
        - 教育背景：...

        ## Core Interests
        - ...

        ## Personality Traits
        - ...
        ```

        **Goals 格式**：
        ```markdown
        # Current Goals

        ## Learning Goals
        - ...

        ## Career Goals
        - ...

        ## Short-term Needs
        - ...
        ```

        ---

        **对话内容**：
        \(conversationText)

        ---

        请严格按照 JSON 格式输出，不要添加其他说明文字。
        """

        let response = try await llmService.generateText(prompt: prompt)

        // 解析 JSON 响应
        if let data = response.data(using: String.Encoding.utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

            // 更新 profile
            if let hasProfile = json["hasProfileInfo"] as? Bool, hasProfile,
               let profileContent = json["profile"] as? String, !profileContent.isEmpty {
                print("📝 从聊天中提取到用户画像")
                try updateProfile(profileContent)
            }

            // 更新 goals
            if let hasGoals = json["hasGoalsInfo"] as? Bool, hasGoals,
               let goalsContent = json["goals"] as? String, !goalsContent.isEmpty {
                print("🎯 从聊天中提取到用户目标")
                try updateGoals(goalsContent)
            }

            // 如果有更新，重新生成摘要
            if (json["hasProfileInfo"] as? Bool == true) || (json["hasGoalsInfo"] as? Bool == true) {
                let summary = try await generateSummary()
                try updateSummary(summary)
                print("✅ 记忆已从聊天中更新")
            }
        }
    }

    // MARK: - 记忆压缩

    /// 压缩记忆内容
    private func compressMemory(content: String, type: MemoryFileType, llmService: LLMService) async throws -> String {
        print("🗜️ 压缩 \(type.rawValue)...")

        let targetLength: Int
        let fileDescription: String

        switch type {
        case .profile:
            targetLength = 500
            fileDescription = "用户画像"
        case .preferences:
            targetLength = 800
            fileDescription = "播客偏好"
        case .goals:
            targetLength = 500
            fileDescription = "当前目标"
        case .summary:
            targetLength = 300
            fileDescription = "记忆摘要"
        }

        let prompt = """
        请将以下\(fileDescription)内容压缩到 \(targetLength) 字以内，保留最关键的信息。

        **压缩原则**：
        1. 保留核心信息和关键数据
        2. 删除冗余描述和重复内容
        3. 使用简洁的表达方式
        4. 保持原有的 Markdown 格式结构

        **原文内容**：
        \(content)

        请直接输出压缩后的内容，不要添加其他说明文字。
        """

        let compressed = try await llmService.generateText(prompt: prompt)

        print("✅ 压缩完成: \(content.count) 字 → \(compressed.count) 字")
        return compressed
    }

    // MARK: - 调试方法

    /// 获取所有记忆文件的状态
    func getMemoryStatus() -> [String: Any] {
        return [
            "memoryDirectory": memoryDirectory.path,
            "profileExists": loadMemory(.profile) != nil,
            "preferencesExists": loadMemory(.preferences) != nil,
            "goalsExists": loadMemory(.goals) != nil,
            "summaryExists": loadMemory(.summary) != nil,
            "lastUpdateDate": lastUpdateDate?.ISO8601Format() ?? "never"
        ]
    }
}

// MARK: - 错误类型

enum MemoryError: LocalizedError {
    case behaviorTrackerNotAvailable
    case llmServiceNotAvailable
    case fileNotFound(MemoryFileType)
    case invalidContent

    var errorDescription: String? {
        switch self {
        case .behaviorTrackerNotAvailable:
            return "行为追踪器不可用"
        case .llmServiceNotAvailable:
            return "LLM 服务不可用，请先在设置中配置 API Key"
        case .fileNotFound(let type):
            return "记忆文件不存在: \(type.rawValue)"
        case .invalidContent:
            return "记忆内容无效"
        }
    }
}
