import Foundation
import SwiftData

/// 用户行为追踪服务
@MainActor
class BehaviorTracker: ObservableObject {
    private let modelContext: ModelContext

    // 当前播放会话
    @Published var currentPlaybackSession: PlaybackSession?

    // 记忆管理器引用（用于自动更新记忆）
    weak var memoryManager: MemoryManager?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - 播放行为追踪

    /// 开始播放会话
    func startPlaybackSession(podcast: Podcast, startPosition: Double = 0.0) {
        // 结束之前的会话（如果有）
        if currentPlaybackSession != nil {
            endPlaybackSession(finalPosition: startPosition)
        }

        // 创建新会话
        let session = PlaybackSession(
            podcastId: podcast.id,
            podcastTitle: podcast.title,
            podcastTopics: podcast.topics,
            totalDuration: podcast.duration,
            startPosition: startPosition
        )
        modelContext.insert(session)
        currentPlaybackSession = session

        // 记录事件
        recordEvent(.playStart, podcastId: podcast.id, details: [
            "title": podcast.title,
            "topics": podcast.topics,
            "startPosition": startPosition
        ])

        print("📊 开始播放会话: \(podcast.title)")
    }

    /// 更新播放进度
    func updatePlaybackProgress(currentPosition: Double, playbackSpeed: Double) {
        guard let session = currentPlaybackSession else { return }
        session.updateProgress(currentPosition: currentPosition, playbackSpeed: playbackSpeed)
        try? modelContext.save()
    }

    /// 记录暂停
    func recordPause() {
        guard let session = currentPlaybackSession else { return }
        session.recordPause()
        recordEvent(.playPause, podcastId: session.podcastId)
        try? modelContext.save()
    }

    /// 记录恢复播放
    func recordResume() {
        guard let session = currentPlaybackSession else { return }
        recordEvent(.playResume, podcastId: session.podcastId)
    }

    /// 记录跳转
    func recordSeek(from: Double, to: Double) {
        guard let session = currentPlaybackSession else { return }
        session.recordSeek(from: from, to: to)
        recordEvent(.playSeek, podcastId: session.podcastId, details: [
            "from": from,
            "to": to,
            "delta": to - from
        ])
        try? modelContext.save()
    }

    /// 记录播放速度变化
    func recordSpeedChange(speed: Double) {
        guard let session = currentPlaybackSession else { return }
        recordEvent(.playSpeedChange, podcastId: session.podcastId, details: [
            "speed": speed
        ])
    }

    /// 结束播放会话
    func endPlaybackSession(finalPosition: Double) {
        guard let session = currentPlaybackSession else { return }

        session.endSession(finalPosition: finalPosition)

        // 记录事件
        let eventType: BehaviorEventType = session.isCompleted ? .playComplete : .playExit
        recordEvent(eventType, podcastId: session.podcastId, details: [
            "completionRate": session.completionRate,
            "playedDuration": session.playedDuration,
            "pauseCount": session.pauseCount,
            "seekCount": session.seekCount
        ])

        // 更新话题偏好
        updateTopicPreferences(from: session)

        // 创建收听历史记录
        createListeningHistory(from: session)

        try? modelContext.save()
        currentPlaybackSession = nil

        print("📊 结束播放会话: 完播率 \(Int(session.completionRate * 100))%")

        // 检查是否需要自动更新记忆
        checkAndUpdateMemory()
    }

    /// 检查并自动更新记忆
    private func checkAndUpdateMemory() {
        guard let memoryManager = memoryManager else { return }

        // 获取总播放次数
        let totalSessions = getRecentPlaybackSessions(limit: 1000).count

        // 每 10 次播放触发一次更新
        if totalSessions % 10 == 0 && totalSessions > 0 {
            print("🔄 达到 \(totalSessions) 次播放，自动更新记忆...")

            Task {
                do {
                    try await memoryManager.updateMemoryFromBehavior()
                    print("✅ 记忆自动更新完成")
                } catch {
                    print("❌ 记忆自动更新失败: \(error)")
                }
            }
        }
    }

    // MARK: - 内容交互追踪

    /// 记录播客查看
    func recordPodcastView(podcast: Podcast, sourceScreen: String? = nil) {
        let interaction = ContentInteraction(
            interactionType: .view,
            contentType: "podcast",
            contentId: podcast.id,
            contentTitle: podcast.title,
            sourceScreen: sourceScreen,
            topicTags: podcast.topics
        )
        modelContext.insert(interaction)

        recordEvent(.podcastView, podcastId: podcast.id, details: [
            "title": podcast.title,
            "topics": podcast.topics
        ])

        try? modelContext.save()
    }

    /// 记录播客生成
    func recordPodcastGeneration(podcast: Podcast, config: [String: Any]) {
        let interaction = ContentInteraction(
            interactionType: .generate,
            contentType: "podcast",
            contentId: podcast.id,
            contentTitle: podcast.title,
            topicTags: podcast.topics,
            details: config
        )
        modelContext.insert(interaction)

        recordEvent(.podcastGenerate, podcastId: podcast.id, topicName: podcast.topics.first, details: config)

        // 更新话题偏好
        for topic in podcast.topics {
            if let preference = getOrCreateTopicPreference(topicName: topic) {
                preference.recordGeneration(wasPlayed: false)
            }
        }

        try? modelContext.save()
    }

    // MARK: - 话题管理追踪

    /// 记录添加话题
    func recordTopicAdd(topicName: String) {
        recordEvent(.topicAdd, topicName: topicName)

        // 创建话题偏好记录
        let preference = getOrCreateTopicPreference(topicName: topicName)
        preference?.recordView()

        try? modelContext.save()
    }

    /// 记录删除话题
    func recordTopicRemove(topicName: String) {
        recordEvent(.topicRemove, topicName: topicName, details: [
            "reason": "user_deleted"
        ])

        // 更新话题偏好评分（大幅降低）
        if let preference = getOrCreateTopicPreference(topicName: topicName) {
            preference.preferenceScore = max(preference.preferenceScore - 50, 0)
        }

        try? modelContext.save()
    }

    /// 记录话题优先级变化
    func recordTopicPriorityChange(topicName: String, oldPriority: Int, newPriority: Int) {
        recordEvent(.topicPriorityChange, topicName: topicName, details: [
            "oldPriority": oldPriority,
            "newPriority": newPriority
        ])

        try? modelContext.save()
    }

    // MARK: - 聊天交互追踪

    /// 记录聊天消息
    func recordChatMessage(message: ChatMessage, extractedTopics: [String] = []) {
        let eventType: BehaviorEventType = message.podcastId != nil ? .chatWithContext : .chatSend

        recordEvent(eventType, podcastId: message.podcastId, details: [
            "hasContext": message.podcastId != nil,
            "messageLength": message.content.count,
            "extractedTopics": extractedTopics
        ])

        // 更新提及的话题偏好
        for topic in extractedTopics {
            if let preference = getOrCreateTopicPreference(topicName: topic) {
                preference.recordChatMention()
            }
        }

        try? modelContext.save()
    }

    // MARK: - 私有辅助方法

    /// 记录通用事件
    private func recordEvent(_ eventType: BehaviorEventType, podcastId: UUID? = nil, topicName: String? = nil, details: [String: Any]? = nil) {
        let event = UserBehaviorEvent(
            eventType: eventType,
            podcastId: podcastId,
            topicName: topicName,
            details: details
        )
        modelContext.insert(event)
    }

    /// 更新话题偏好（从播放会话）
    private func updateTopicPreferences(from session: PlaybackSession) {
        for topic in session.podcastTopics {
            if let preference = getOrCreateTopicPreference(topicName: topic) {
                preference.recordPlay(
                    completionRate: session.completionRate,
                    duration: session.playedDuration
                )
            }
        }
    }

    /// 创建收听历史记录
    private func createListeningHistory(from session: PlaybackSession) {
        let history = ListeningHistory(
            podcastId: session.podcastId,
            podcastTitle: session.podcastTitle,
            duration: session.playedDuration,
            completionRate: session.completionRate
        )
        modelContext.insert(history)
    }

    /// 获取或创建话题偏好
    private func getOrCreateTopicPreference(topicName: String) -> TopicPreference? {
        // 查询现有偏好
        let descriptor = FetchDescriptor<TopicPreference>(
            predicate: #Predicate { $0.topicName == topicName }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }

        // 创建新偏好
        let preference = TopicPreference(topicName: topicName)
        modelContext.insert(preference)
        return preference
    }

    // MARK: - 查询方法

    /// 获取话题偏好列表（按评分排序）
    func getTopicPreferences(limit: Int = 20) -> [TopicPreference] {
        var descriptor = FetchDescriptor<TopicPreference>(
            sortBy: [SortDescriptor(\.preferenceScore, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// 获取最近的播放会话
    func getRecentPlaybackSessions(limit: Int = 50) -> [PlaybackSession] {
        var descriptor = FetchDescriptor<PlaybackSession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// 获取用户行为事件
    func getBehaviorEvents(eventType: BehaviorEventType? = nil, limit: Int = 100) -> [UserBehaviorEvent] {
        var descriptor: FetchDescriptor<UserBehaviorEvent>

        if let eventType = eventType {
            descriptor = FetchDescriptor<UserBehaviorEvent>(
                predicate: #Predicate { $0.eventType == eventType.rawValue },
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<UserBehaviorEvent>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
        }

        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
