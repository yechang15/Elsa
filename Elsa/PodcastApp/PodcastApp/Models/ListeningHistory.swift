import Foundation
import SwiftData

/// 收听历史模型
@Model
final class ListeningHistory {
    var id: UUID
    var podcastId: UUID
    var podcastTitle: String
    var listenedAt: Date
    var duration: Int // 收听时长（秒）
    var completionRate: Double // 完播率 (0.0-1.0)

    init(podcastId: UUID, podcastTitle: String, duration: Int, completionRate: Double) {
        self.id = UUID()
        self.podcastId = podcastId
        self.podcastTitle = podcastTitle
        self.listenedAt = Date()
        self.duration = duration
        self.completionRate = completionRate
    }

    /// 格式化收听时间
    var formattedListenedAt: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: listenedAt)
    }

    /// 格式化时长
    var formattedDuration: String {
        let minutes = duration / 60
        return "\(minutes) 分钟"
    }

    /// 完播率百分比
    var completionPercentage: Int {
        Int(completionRate * 100)
    }
}
