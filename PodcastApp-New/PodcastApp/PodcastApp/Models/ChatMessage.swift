import Foundation
import SwiftData

/// 对话消息
@Model
final class ChatMessage {
    var id: UUID
    var content: String
    var role: String // "user" 或 "assistant"
    var timestamp: Date

    // 上下文信息
    var podcastId: UUID? // 关联的播客ID
    var podcastTitle: String? // 播客标题（冗余存储，方便显示）
    var playbackTime: Double? // 提问时的播放位置（秒）
    var contextSegmentsData: Data? // 相关的脚本段落（序列化存储）

    init(content: String, role: String, podcastId: UUID? = nil, podcastTitle: String? = nil, playbackTime: Double? = nil, contextSegments: [ScriptSegment]? = nil) {
        self.id = UUID()
        self.content = content
        self.role = role
        self.timestamp = Date()
        self.podcastId = podcastId
        self.podcastTitle = podcastTitle
        self.playbackTime = playbackTime

        // 序列化 contextSegments
        if let segments = contextSegments {
            self.contextSegmentsData = try? JSONEncoder().encode(segments)
        }
    }

    /// 获取上下文段落
    var contextSegments: [ScriptSegment]? {
        guard let data = contextSegmentsData else { return nil }
        return try? JSONDecoder().decode([ScriptSegment].self, from: data)
    }

    /// 格式化时间显示
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: timestamp)
    }

    /// 是否有播客上下文
    var hasPodcastContext: Bool {
        return podcastId != nil
    }

    /// 格式化播放位置
    var formattedPlaybackTime: String? {
        guard let time = playbackTime else { return nil }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
