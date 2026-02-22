import Foundation

/// 播客脚本段落（带时间戳）
struct ScriptSegment: Codable, Identifiable {
    let id: UUID
    let speaker: String // "主播A" 或 "主播B"
    let content: String // 对话内容
    let startTime: Double // 开始时间（秒）
    let endTime: Double // 结束时间（秒）
    var sourceArticleIndices: [Int]? // 来源文章索引（可选）

    init(speaker: String, content: String, startTime: Double, endTime: Double, sourceArticleIndices: [Int]? = nil) {
        self.id = UUID()
        self.speaker = speaker
        self.content = content
        self.startTime = startTime
        self.endTime = endTime
        self.sourceArticleIndices = sourceArticleIndices
    }

    /// 格式化时间显示
    var formattedTimeRange: String {
        let startMin = Int(startTime) / 60
        let startSec = Int(startTime) % 60
        let endMin = Int(endTime) / 60
        let endSec = Int(endTime) % 60
        return String(format: "%d:%02d - %d:%02d", startMin, startSec, endMin, endSec)
    }

    /// 检查给定时间是否在此段落范围内
    func contains(time: Double) -> Bool {
        return time >= startTime && time < endTime
    }
}
