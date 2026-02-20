import Foundation

// MARK: - AgentTool 协议

/// 统一工具接口，所有工具（In-App Adapter 或未来的 MCP Adapter）均实现此协议
protocol AgentTool: Sendable {
    /// 工具唯一 id，如 "weather"、"calendar"、"rss"
    var name: String { get }
    /// 工具描述，供编排引擎理解工具能力
    var description: String { get }
    /// 执行工具，返回结构化文本结果
    func execute(params: [String: Any]) async throws -> String
}

// MARK: - Skill 配置模型

/// Skill 触发场景
enum SkillScene: String, Codable {
    case podcastGenerate = "podcast_generate"
    case podcastRecommend = "podcast_recommend"
    case chat = "chat"
    case homeOpen = "home_open"
    case scheduled = "scheduled"
    case manual = "manual"
}

/// Skill 中单个工具的调用配置
struct SkillToolConfig: Codable {
    let tool: String                    // 工具 id
    let params: [String: AnyCodable]    // 调用参数
    let required: Bool                  // false 表示工具不可用时仍可继续
}

/// 合并策略
enum MergePolicy: String, Codable {
    case concatSummary = "concat_summary"
    case structuredBriefing = "structured_briefing"
    case meetingBrief = "meeting_brief"
    case recommendationScore = "recommendation_score"
}

/// 输出目标
enum OutputTarget: String, Codable {
    case promptContext = "prompt_context"
    case podcastGenerate = "podcast_generate"
    case chat = "chat"
    case recommendList = "recommend_list"
}

/// Skill 配置
struct SkillConfig: Codable {
    let id: String
    let name: String
    let description: String
    let triggers: [SkillScene]
    let tools: [SkillToolConfig]
    let mergePolicy: MergePolicy
    let outputTo: [OutputTarget]
    var enabled: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, description, triggers, tools, enabled
        case mergePolicy = "merge_policy"
        case outputTo = "output_to"
    }
}

// MARK: - AnyCodable 辅助类型

/// 用于 Codable 中存储任意 JSON 值
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let string = try? container.decode(String.self) {
            value = string
        } else {
            value = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let int as Int: try container.encode(int)
        case let double as Double: try container.encode(double)
        case let bool as Bool: try container.encode(bool)
        case let string as String: try container.encode(string)
        default: try container.encode("")
        }
    }
}
