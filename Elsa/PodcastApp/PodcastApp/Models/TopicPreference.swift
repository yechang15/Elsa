import Foundation
import SwiftData

/// 话题偏好统计
@Model
final class TopicPreference {
    var id: UUID
    var topicName: String
    var lastUpdated: Date

    // 播放统计
    var totalPlays: Int              // 总播放次数
    var completedPlays: Int          // 完播次数
    var averageCompletionRate: Double // 平均完播率
    var totalPlayTime: Int           // 总播放时长（秒）

    // 生成统计
    var totalGenerations: Int        // 总生成次数
    var playedGenerations: Int       // 生成后播放的次数

    // 交互统计
    var viewCount: Int               // 查看次数
    var chatMentionCount: Int        // 聊天中提及次数

    // 时间统计
    var firstInteractionDate: Date?  // 首次交互时间
    var lastInteractionDate: Date?   // 最近交互时间
    var recentPlayCount: Int         // 最近7天播放次数

    // 偏好评分（0-100）
    var preferenceScore: Double

    init(topicName: String) {
        self.id = UUID()
        self.topicName = topicName
        self.lastUpdated = Date()
        self.totalPlays = 0
        self.completedPlays = 0
        self.averageCompletionRate = 0.0
        self.totalPlayTime = 0
        self.totalGenerations = 0
        self.playedGenerations = 0
        self.viewCount = 0
        self.chatMentionCount = 0
        self.recentPlayCount = 0
        self.preferenceScore = 50.0 // 默认中等偏好
    }

    /// 记录播放
    func recordPlay(completionRate: Double, duration: Int) {
        self.totalPlays += 1
        if completionRate >= 0.8 {
            self.completedPlays += 1
        }
        self.totalPlayTime += duration
        self.lastInteractionDate = Date()

        // 更新平均完播率
        self.averageCompletionRate = (self.averageCompletionRate * Double(totalPlays - 1) + completionRate) / Double(totalPlays)

        // 更新偏好评分
        updatePreferenceScore()
    }

    /// 记录生成
    func recordGeneration(wasPlayed: Bool = false) {
        self.totalGenerations += 1
        if wasPlayed {
            self.playedGenerations += 1
        }
        self.lastInteractionDate = Date()
        updatePreferenceScore()
    }

    /// 记录查看
    func recordView() {
        self.viewCount += 1
        self.lastInteractionDate = Date()
        if firstInteractionDate == nil {
            self.firstInteractionDate = Date()
        }
    }

    /// 记录聊天提及
    func recordChatMention() {
        self.chatMentionCount += 1
        self.lastInteractionDate = Date()
        updatePreferenceScore()
    }

    /// 更新偏好评分（综合算法）
    private func updatePreferenceScore() {
        var score: Double = 0.0

        // 完播率权重：40分
        score += averageCompletionRate * 40

        // 播放频率权重：30分
        if totalPlays > 0 {
            let playFrequency = min(Double(totalPlays) / 10.0, 1.0) // 10次以上满分
            score += playFrequency * 30
        }

        // 生成转化率权重：15分
        if totalGenerations > 0 {
            let conversionRate = Double(playedGenerations) / Double(totalGenerations)
            score += conversionRate * 15
        }

        // 聊天提及权重：10分
        if chatMentionCount > 0 {
            let chatScore = min(Double(chatMentionCount) / 5.0, 1.0) // 5次以上满分
            score += chatScore * 10
        }

        // 最近活跃度权重：5分
        if let lastDate = lastInteractionDate {
            let daysSinceLastInteraction = Date().timeIntervalSince(lastDate) / 86400
            if daysSinceLastInteraction < 7 {
                score += 5.0
            } else if daysSinceLastInteraction < 30 {
                score += 2.5
            }
        }

        self.preferenceScore = min(score, 100.0)
        self.lastUpdated = Date()
    }

    /// 偏好等级
    var preferenceLevel: String {
        if preferenceScore >= 80 {
            return "非常感兴趣"
        } else if preferenceScore >= 60 {
            return "比较感兴趣"
        } else if preferenceScore >= 40 {
            return "一般"
        } else if preferenceScore >= 20 {
            return "不太感兴趣"
        } else {
            return "不感兴趣"
        }
    }

    /// 生成转化率
    var generationConversionRate: Double {
        guard totalGenerations > 0 else { return 0.0 }
        return Double(playedGenerations) / Double(totalGenerations)
    }
}
