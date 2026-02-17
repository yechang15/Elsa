import Foundation

/// 豆包播客API服务
/// 文档：https://www.volcengine.com/docs/6561/1293828
class DoubaoPodcastService: NSObject, URLSessionWebSocketDelegate {
    private let apiKey: String
    private let appKey: String
    private let resourceId = "volc.service_type.10050"

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var audioData = Data()
    private var isFinished = false
    private var progressHandler: ((String) -> Void)?

    init(apiKey: String) {
        self.apiKey = apiKey
        super.init()
    }

    /// 生成播客音频（一体化模式）
    func generatePodcast(
        inputText: String,
        voiceA: String,
        voiceB: String,
        outputURL: URL,
        progressHandler: @escaping (String) -> Void
    ) async throws {
        self.progressHandler = progressHandler
        self.audioData = Data()
        self.isFinished = false

        // 1. 建立WebSocket连接
        try await connect()

        // 2. 发送StartSession请求
        let sessionId = UUID().uuidString
        try await sendStartSession(
            sessionId: sessionId,
            inputText: inputText,
            voiceA: voiceA,
            voiceB: voiceB
        )

        // 3. 接收音频数据
        try await receiveMessages()

        // 4. 保存音频文件
        try audioData.write(to: outputURL)
        progressHandler("✅ 音频已保存到: \(outputURL.lastPathComponent)")

        // 5. 关闭连接
        await disconnect()
    }

    // MARK: - WebSocket连接管理

    private func connect() async throws {
        let url = URL(string: "wss://openspeech.bytedance.com/api/v3/sami/podcasttts")!
        var request = URLRequest(url: url)

        // 设置请求头 - 使用正确的请求头名称
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Access-Key")  // 注意：是Access-Key不是Access-Token
        request.setValue(resourceId, forHTTPHeaderField: "X-Api-Resource-Id")
        request.setValue(appKey, forHTTPHeaderField: "X-Api-App-Key")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Api-Request-Id")

        // 打印请求头用于调试
        NSLog("🔍 WebSocket请求头:")
        NSLog("  X-Api-Access-Key: \(apiKey)")
        NSLog("  X-Api-Resource-Id: \(resourceId)")
        NSLog("  X-Api-App-Key: \(appKey)")

        progressHandler?("🔍 准备连接...")
        progressHandler?("🔍 API Key: \(apiKey.prefix(8))...")

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        webSocketTask = session?.webSocketTask(with: request)
        webSocketTask?.resume()

        progressHandler?("🔗 WebSocket连接已建立")
    }

    private func disconnect() async {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        session?.invalidateAndCancel()
        progressHandler?("🔗 WebSocket连接已关闭")
    }

    // MARK: - 协议帧构建

    private func sendStartSession(
        sessionId: String,
        inputText: String,
        voiceA: String,
        voiceB: String
    ) async throws {
        // 构建payload
        let payload: [String: Any] = [
            "input_id": "podcast_\(UUID().uuidString)",
            "input_text": inputText,
            "action": 0,
            "use_head_music": false,
            "use_tail_music": false,
            "audio_config": [
                "format": "mp3",
                "sample_rate": 24000,
                "speech_rate": 0
            ],
            "speaker_info": [
                "random_order": true,
                "speakers": [voiceA, voiceB]
            ]
        ]

        let payloadData = try JSONSerialization.data(withJSONObject: payload)

        // 构建二进制帧
        let frame = buildFrame(
            messageType: 0b1001,
            flags: 0b0100,
            serialization: 0b0001,
            eventCode: 150, // StartSession
            sessionId: sessionId,
            payload: payloadData
        )

        // 发送帧
        try await webSocketTask?.send(.data(frame))
        progressHandler?("📤 已发送StartSession请求")
    }

    private func buildFrame(
        messageType: UInt8,
        flags: UInt8,
        serialization: UInt8,
        eventCode: UInt32,
        sessionId: String,
        payload: Data
    ) -> Data {
        var frame = Data()

        // Header (4 bytes)
        frame.append(0b00010001) // Byte 0: version=1, header_size=1
        frame.append((messageType << 4) | flags) // Byte 1
        frame.append((serialization << 4) | 0b0000) // Byte 2: no compression
        frame.append(0b00000000) // Byte 3: reserved

        // Event code (4 bytes, big-endian)
        frame.append(contentsOf: withUnsafeBytes(of: eventCode.bigEndian) { Data($0) })

        // Session ID length (4 bytes, big-endian)
        let sessionIdData = sessionId.data(using: .utf8)!
        let sessionIdLength = UInt32(sessionIdData.count)
        frame.append(contentsOf: withUnsafeBytes(of: sessionIdLength.bigEndian) { Data($0) })

        // Session ID
        frame.append(sessionIdData)

        // Payload length (4 bytes, big-endian)
        let payloadLength = UInt32(payload.count)
        frame.append(contentsOf: withUnsafeBytes(of: payloadLength.bigEndian) { Data($0) })

        // Payload
        frame.append(payload)

        return frame
    }

    // MARK: - 接收消息

    private func receiveMessages() async throws {
        while !isFinished {
            do {
                guard let message = try await webSocketTask?.receive() else {
                    break
                }

                switch message {
                case .data(let data):
                    try handleFrame(data)
                case .string(let text):
                    print("📨 收到文本消息: \(text)")
                    progressHandler?("📨 服务器消息: \(text)")
                @unknown default:
                    break
                }
            } catch {
                print("❌ WebSocket错误: \(error)")
                print("❌ 错误详情: \(error.localizedDescription)")
                if let urlError = error as? URLError {
                    print("❌ URLError code: \(urlError.code.rawValue)")
                    print("❌ URLError description: \(urlError.localizedDescription)")
                }
                throw error
            }
        }
    }

    private func handleFrame(_ data: Data) throws {
        guard data.count >= 4 else { return }

        // 解析header
        let _ = (data[1] & 0xF0) >> 4 // messageType
        let serialization = (data[2] & 0xF0) >> 4

        var offset = 4

        // 读取event code (4 bytes, big-endian)
        guard data.count >= offset + 4 else { return }
        let eventCode = data[offset..<offset+4].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        offset += 4

        // 读取session ID length (4 bytes, big-endian)
        guard data.count >= offset + 4 else { return }
        let sessionIdLength = data[offset..<offset+4].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        offset += 4

        // 读取session ID
        guard data.count >= offset + Int(sessionIdLength) else { return }
        offset += Int(sessionIdLength)

        // 读取payload length (4 bytes, big-endian)
        guard data.count >= offset + 4 else { return }
        let payloadLength = data[offset..<offset+4].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        offset += 4

        // 读取payload
        guard data.count >= offset + Int(payloadLength) else { return }
        let payloadData = data[offset..<offset+Int(payloadLength)]

        // 处理不同的事件
        handleEvent(eventCode: eventCode, serialization: serialization, payload: payloadData)
    }

    private func handleEvent(eventCode: UInt32, serialization: UInt8, payload: Data) {
        switch eventCode {
        case 150: // SessionStarted
            progressHandler?("✅ 会话已开始")

        case 360: // PodcastRoundStart
            if serialization == 0b0001, let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] {
                let roundId = json["round_id"] as? Int ?? 0
                let _ = json["speaker"] as? String ?? "" // speaker
                let text = json["text"] as? String ?? ""
                if roundId == -1 {
                    progressHandler?("🎵 开头音乐")
                } else if roundId == 9999 {
                    progressHandler?("🎵 结尾音频")
                } else {
                    progressHandler?("🎙️ 轮次 \(roundId): \(text)")
                }
            }

        case 361: // PodcastRoundResponse (音频数据)
            audioData.append(payload)
            progressHandler?("📥 接收音频: \(payload.count) bytes")

        case 362: // PodcastRoundEnd
            if serialization == 0b0001, let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] {
                if let duration = json["audio_duration"] as? Double {
                    progressHandler?("✅ 轮次结束，时长: \(String(format: "%.2f", duration))秒")
                }
            }

        case 363: // PodcastEnd
            progressHandler?("🎉 播客生成完成")

        case 152: // SessionFinished
            progressHandler?("✅ 会话已结束")
            isFinished = true

        case 154: // UsageResponse
            if serialization == 0b0001, let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
               let usage = json["usage"] as? [String: Any] {
                let inputTokens = usage["input_text_tokens"] as? Int ?? 0
                let outputTokens = usage["output_audio_tokens"] as? Int ?? 0
                progressHandler?("📊 用量: 输入\(inputTokens) tokens, 输出\(outputTokens) tokens")
            }

        default:
            print("❌ 未知事件: \(eventCode)")
            progressHandler?("⚠️ 未知事件: \(eventCode)")
        }
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("✅ WebSocket已打开，协议: \(`protocol` ?? "无")")
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("🔒 WebSocket已关闭，代码: \(closeCode.rawValue)")
        if let reason = reason, let reasonString = String(data: reason, encoding: .utf8) {
            print("🔒 关闭原因: \(reasonString)")
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            NSLog("❌ URLSession任务错误: \(error)")
            NSLog("❌ 错误详情: \(error.localizedDescription)")
            progressHandler?("❌ 连接错误: \(error.localizedDescription)")

            if let httpResponse = task.response as? HTTPURLResponse {
                NSLog("❌ HTTP状态码: \(httpResponse.statusCode)")
                NSLog("❌ HTTP响应头: \(httpResponse.allHeaderFields)")
                progressHandler?("❌ HTTP状态码: \(httpResponse.statusCode)")
            }
        }
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
