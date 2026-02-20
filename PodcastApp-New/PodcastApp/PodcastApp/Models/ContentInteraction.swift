import Foundation
import SwiftData

/// 内容交互类型
enum InteractionType: String, Codable {
    case view = "view"              // 查看
    case click = "click"            // 点击
    case generate = "generate"      // 生成
    case delete = "delete"          // 删除
    case share = "share"            // 分享
    case favorite = "favorite"      // 收藏
}

/// 内容交互记录
@Model
final class ContentInteraction {
    var id: UUID
    var interactionType: String // InteractionType的rawValue
    var timestamp: Date

    // 内容信息
    var contentType: String      // "podcast", "topic", "chat"
    var contentId: UUID?         // 内容ID
    var contentTitle: String?    // 内容标题

    // 上下文信息
    var sourceScreen: String?    // 来源页面
    var topicTags: [String]      // 关联的话题标签

    // 交互详情
    var durationSeconds: Int?    // 交互时长（秒）
    var detailsData: Data?       // 额外详情

    init(interactionType: InteractionType, contentType: String, contentId: UUID? = nil, contentTitle: String? = nil, sourceScreen: String? = nil, topicTags: [String] = [], durationSeconds: Int? = nil, details: [String: Any]? = nil) {
        self.id = UUID()
        self.interactionType = interactionType.rawValue
        self.timestamp = Date()
        self.contentType = contentType
        self.contentId = contentId
        self.contentTitle = contentTitle
        self.sourceScreen = sourceScreen
        self.topicTags = topicTags
        self.durationSeconds = durationSeconds

        if let details = details {
            self.detailsData = try? JSONSerialization.data(withJSONObject: details)
        }
    }

    /// 获取详情
    var details: [String: Any]? {
        guard let data = detailsData else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
