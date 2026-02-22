import Foundation

// 播客生成步骤
enum GenerationStep: Int {
    case idle = 0
    case fetchingRSS = 1
    case generatingScript = 2
    case generatingAudio = 3
    case saving = 4
    case completed = 5

    var title: String {
        switch self {
        case .idle: return "准备中"
        case .fetchingRSS: return "获取 RSS 内容"
        case .generatingScript: return "生成播客脚本"
        case .generatingAudio: return "合成音频"
        case .saving: return "保存播客"
        case .completed: return "完成"
        }
    }

    var description: String {
        switch self {
        case .idle: return "正在准备生成播客..."
        case .fetchingRSS: return "正在从 RSS 源获取最新文章..."
        case .generatingScript: return "AI 正在根据文章内容生成对话脚本..."
        case .generatingAudio: return "正在将脚本转换为音频文件..."
        case .saving: return "正在保存播客到数据库..."
        case .completed: return "播客生成完成！"
        }
    }

    static var allSteps: [GenerationStep] {
        [.fetchingRSS, .generatingScript, .generatingAudio, .saving]
    }
}
