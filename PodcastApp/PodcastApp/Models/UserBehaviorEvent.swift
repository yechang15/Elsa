import Foundation
import SwiftData

/// 用户行为事件类型
enum BehaviorEventType: String, Codable {
    // 播放行为
    case playStart = "play_start"           // 开始播放
    case playPause = "play_pause"           // 暂停播放
    case playResume = "play_resume"         // 恢复播放
    case playComplete = "play_complete"     // 播放完成
    case playExit = "play_exit"             // 中途退出
    case playSeek = "play_seek"             // 跳转播放位置
    case playSpeedChange = "play_speed_change" // 改变播放速度

    // 浏览行为
    case podcastView = "podcast_view"       // 查看播客详情
    case podcastListBrowse = "podcast_list_browse" // 浏览播客列表
    case topicView = "topic_view"           // 查看话题

    // 生成行为
    case podcastGenerate = "podcast_generate" // 生成播客
    case podcastGenerateComplete = "podcast_generate_complete" // 生成完成

    // 话题管理
    case topicAdd = "topic_add"             // 添加话题
    case topicRemove = "topic_remove"       // 删除话题
    case topicPriorityChange = "topic_priority_change" // 调整话题优先级

    // 聊天交互
    case chatSend = "chat_send"             // 发送聊天消息
    case chatWithContext = "chat_with_context" // 带播客上下文的聊天

    // 配置变更
    case configChange = "config_change"     // 配置变更
}

/// 用户行为事件 - 通用事件记录
@Model
final class UserBehaviorEvent {
    var id: UUID
    var eventType: String // BehaviorEventType的rawValue
    var timestamp: Date

    // 关联对象
    var podcastId: UUID?
    var topicName: String?

    // 事件详情（JSON格式存储）
    var detailsData: Data?

    init(eventType: BehaviorEventType, podcastId: UUID? = nil, topicName: String? = nil, details: [String: Any]? = nil) {
        self.id = UUID()
        self.eventType = eventType.rawValue
        self.timestamp = Date()
        self.podcastId = podcastId
        self.topicName = topicName

        if let details = details {
            self.detailsData = try? JSONSerialization.data(withJSONObject: details)
        }
    }

    /// 获取事件详情
    var details: [String: Any]? {
        guard let data = detailsData else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
