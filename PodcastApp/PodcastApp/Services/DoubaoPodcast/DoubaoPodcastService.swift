import Foundation

/// 豆包播客API服务
/// 文档：https://www.volcengine.com/docs/6561/1293828
class DoubaoPodcastService {
    private let appId: String
    private let accessToken: String

    init(appId: String, accessToken: String) {
        self.appId = appId
        self.accessToken = accessToken
    }

    /// 生成播客音频（一体化模式）
    /// - Parameters:
    ///   - inputText: 输入文本
    ///   - voiceA: 主播A语音ID
    ///   - voiceB: 主播B语音ID
    ///   - outputURL: 输出音频文件路径
    ///   - progressHandler: 进度回调
    func generatePodcast(
        inputText: String,
        voiceA: String,
        voiceB: String,
        outputURL: URL,
        progressHandler: @escaping (String) -> Void
    ) async throws {
        // TODO: 实现豆包播客API调用
        // 1. 建立WebSocket连接 (wss://openspeech.bytedance.com/api/v3/sami/podcasttts)
        // 2. 发送StartSession请求（二进制协议）
        // 3. 接收音频数据流
        // 4. 保存音频文件
        // 5. 关闭连接

        throw NSError(
            domain: "DoubaoPodcastService",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "豆包播客API功能尚未实现"]
        )
    }
}

// MARK: - 事件类型定义
extension DoubaoPodcastService {
    enum EventCode: UInt32 {
        case sessionStarted = 150
        case podcastRoundStart = 360
        case podcastRoundResponse = 361
        case podcastRoundEnd = 362
        case podcastEnd = 363
        case sessionFinished = 152
        case usageResponse = 154
    }
}
