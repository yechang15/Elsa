import Foundation
import SwiftData

/// 播放会话 - 记录一次完整的播放行为
@Model
final class PlaybackSession {
    var id: UUID
    var podcastId: UUID
    var podcastTitle: String
    var podcastTopics: [String] // 播客的话题标签

    // 时间信息
    var startTime: Date          // 会话开始时间
    var endTime: Date?           // 会话结束时间
    var totalDuration: Int       // 播客总时长（秒）

    // 播放行为
    var playedDuration: Int      // 实际播放时长（秒）
    var completionRate: Double   // 完播率 (0.0-1.0)
    var startPosition: Double    // 开始播放位置（秒）
    var endPosition: Double      // 结束播放位置（秒）
    var maxPosition: Double      // 播放到的最远位置（秒）

    // 播放特征
    var pauseCount: Int          // 暂停次数
    var seekCount: Int           // 跳转次数
    var playbackSpeed: Double    // 播放速度
    var isCompleted: Bool        // 是否完播

    // 跳过的段落（记录快进跳过的时间段）
    var skippedSegmentsData: Data? // [[startTime, endTime]]

    init(podcastId: UUID, podcastTitle: String, podcastTopics: [String], totalDuration: Int, startPosition: Double = 0.0) {
        self.id = UUID()
        self.podcastId = podcastId
        self.podcastTitle = podcastTitle
        self.podcastTopics = podcastTopics
        self.startTime = Date()
        self.totalDuration = totalDuration
        self.playedDuration = 0
        self.completionRate = 0.0
        self.startPosition = startPosition
        self.endPosition = startPosition
        self.maxPosition = startPosition
        self.pauseCount = 0
        self.seekCount = 0
        self.playbackSpeed = 1.0
        self.isCompleted = false
    }

    /// 更新播放进度
    func updateProgress(currentPosition: Double, playbackSpeed: Double) {
        self.endPosition = currentPosition
        self.maxPosition = max(self.maxPosition, currentPosition)
        self.playbackSpeed = playbackSpeed
        self.completionRate = totalDuration > 0 ? currentPosition / Double(totalDuration) : 0.0
        self.isCompleted = completionRate >= 0.8 // 80%以上认为完播
    }

    /// 记录暂停
    func recordPause() {
        self.pauseCount += 1
    }

    /// 记录跳转
    func recordSeek(from: Double, to: Double) {
        self.seekCount += 1

        // 如果是快进跳过，记录跳过的段落
        if to > from + 5 { // 跳过超过5秒认为是有意跳过
            var skippedSegments = self.skippedSegments
            skippedSegments.append([from, to])
            self.skippedSegmentsData = try? JSONEncoder().encode(skippedSegments)
        }
    }

    /// 结束会话
    func endSession(finalPosition: Double) {
        self.endTime = Date()
        self.endPosition = finalPosition
        self.maxPosition = max(self.maxPosition, finalPosition)
        self.completionRate = totalDuration > 0 ? maxPosition / Double(totalDuration) : 0.0
        self.isCompleted = completionRate >= 0.8

        // 计算实际播放时长
        if let endTime = endTime {
            self.playedDuration = Int(endTime.timeIntervalSince(startTime))
        }
    }

    /// 获取跳过的段落
    var skippedSegments: [[Double]] {
        guard let data = skippedSegmentsData else { return [] }
        return (try? JSONDecoder().decode([[Double]].self, from: data)) ?? []
    }

    /// 兴趣等级（基于完播率）
    var interestLevel: InterestLevel {
        if completionRate >= 0.8 {
            return .high
        } else if completionRate >= 0.5 {
            return .medium
        } else if completionRate >= 0.2 {
            return .low
        } else {
            return .veryLow
        }
    }

    /// 会话时长（分钟）
    var sessionDurationMinutes: Int {
        guard let endTime = endTime else { return 0 }
        return Int(endTime.timeIntervalSince(startTime) / 60)
    }
}

/// 兴趣等级
enum InterestLevel: String, Codable {
    case veryLow = "very_low"   // <20%
    case low = "low"            // 20-50%
    case medium = "medium"      // 50-80%
    case high = "high"          // >=80%
}
