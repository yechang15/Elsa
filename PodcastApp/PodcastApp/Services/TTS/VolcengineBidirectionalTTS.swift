import Foundation

/// 火山引擎双向流式TTS服务
class VolcengineBidirectionalTTS: NSObject {
    private let appId: String
    private let accessToken: String
    private let resourceId: String

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var audioDataBuffer: Data = Data()
    private var isConnected = false
    private var sessionId: String = ""

    // Event codes (根据文档)
    private enum EventCode: Int32 {
        case startConnection = 1
        case finishConnection = 2
        case connectionStarted = 50
        case connectionFinished = 52
        case startSession = 100
        case finishSession = 102
        case sessionStarted = 150
        case sessionFinished = 152
        case taskRequest = 200
        case ttsSentenceStart = 350
        case ttsSentenceEnd = 351
        case ttsResponse = 352  // 音频数据
        case error = 300
    }

    init(appId: String, accessToken: String, resourceId: String = "seed-tts-2.0") {
        self.appId = appId
        self.accessToken = accessToken
        self.resourceId = resourceId
        super.init()
    }

    /// 合成语音
    func synthesize(text: String, voice: String, speed: Float = 1.0) async throws -> Data {
        print("=== 开始合成语音 ===")
        print("文本长度: \(text.count) 字符")
        print("音色: \(voice)")
        print("语速: \(speed)")

        // 验证音色是否与resource ID匹配
        let availableVoices = VolcengineVoices.voices(for: resourceId)
        guard availableVoices.contains(where: { $0.id == voice }) else {
            print("❌ 音色验证失败:")
            print("   选择的音色: \(voice)")
            print("   当前Resource ID: \(resourceId)")
            print("   可用音色: \(availableVoices.map { $0.id }.joined(separator: ", "))")
            throw TTSError.invalidVoice("音色 '\(voice)' 不支持 Resource ID '\(resourceId)'")
        }

        // 重置缓冲区
        audioDataBuffer = Data()

        // 建立连接
        try await connect()

        // 开始会话
        try await startSession(voice: voice, speed: speed)

        // 发送文本
        try await sendText(text)

        // 结束会话并等待音频数据
        try await finishSession()

        // 断开连接
        try await disconnect()

        print("✅ 合成完成，音频数据大小: \(audioDataBuffer.count) 字节")

        // 验证音频数据
        if audioDataBuffer.count == 0 {
            print("⚠️ 警告：音频数据为空")
        } else if audioDataBuffer.count < 100 {
            print("⚠️ 警告：音频数据过小，可能不完整")
        }

        return audioDataBuffer
    }

    // MARK: - WebSocket连接管理

    private func connect() async throws {
        let connectId = UUID().uuidString
        let urlString = "wss://openspeech.bytedance.com/api/v3/tts/bidirection"

        guard let url = URL(string: urlString) else {
            throw TTSError.invalidURL
        }

        var request = URLRequest(url: url)

        // 新版API使用 X-Api-Key
        if appId.contains("-") {
            // 新版API Key格式 (UUID格式)
            request.setValue(appId, forHTTPHeaderField: "X-Api-Key")
        } else {
            // 旧版格式
            request.setValue(appId, forHTTPHeaderField: "X-Api-App-Key")
            request.setValue(accessToken, forHTTPHeaderField: "X-Api-Access-Key")
        }

        request.setValue(resourceId, forHTTPHeaderField: "X-Api-Resource-Id")
        request.setValue(connectId, forHTTPHeaderField: "X-Api-Connect-Id")

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.connectionProxyDictionary = [:] // 禁用代理
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        webSocketTask = session?.webSocketTask(with: request)
        webSocketTask?.resume()

        // 发送StartConnection消息
        try await sendMessage(event: .startConnection, payload: [:])

        // 等待ConnectionStarted响应
        try await waitForEvent(event: .connectionStarted)

        isConnected = true
        print("✅ WebSocket连接已建立")
    }

    private func disconnect() async throws {
        guard isConnected else { return }

        // 发送FinishConnection消息
        try await sendMessage(event: .finishConnection, payload: [:])

        // 等待ConnectionFinished响应
        try await waitForEvent(event: .connectionFinished)

        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        session?.invalidateAndCancel()
        session = nil
        isConnected = false

        print("✅ WebSocket连接已断开")
    }

    // MARK: - 会话管理

    private func startSession(voice: String, speed: Float) async throws {
        sessionId = UUID().uuidString.prefix(12).description // 限制为12字节
        let sessionIdData = sessionId.data(using: .utf8)!

        let payload: [String: Any] = [
            "user": [:],
            "req_params": [
                "text": "",
                "speaker": voice,
                "audio_params": [
                    "format": "mp3",
                    "sample_rate": 24000,
                    "speech_rate": Int((speed - 1.0) * 100)
                ]
            ]
        ]

        try await sendSessionMessage(event: .startSession, sessionId: sessionIdData, payload: payload)
        try await waitForEvent(event: .sessionStarted)

        print("✅ 会话已开始: \(sessionId)")
    }

    private func sendText(_ text: String) async throws {
        let sessionIdData = sessionId.data(using: .utf8)!

        let payload: [String: Any] = [
            "event": EventCode.taskRequest.rawValue,
            "namespace": "BidirectionalTTS",
            "req_params": [
                "text": text
            ]
        ]

        try await sendSessionMessage(event: .taskRequest, sessionId: sessionIdData, payload: payload)
        print("✅ 文本已发送: \(text.prefix(50))...")
    }

    private func finishSession() async throws {
        let sessionIdData = sessionId.data(using: .utf8)!

        let payload: [String: Any] = [
            "event": EventCode.finishSession.rawValue,
            "namespace": "BidirectionalTTS"
        ]

        try await sendSessionMessage(event: .finishSession, sessionId: sessionIdData, payload: payload)

        // 持续接收音频数据直到收到SessionFinished
        try await receiveAudioUntilFinished()

        print("✅ 会话已结束，共接收音频数据: \(audioDataBuffer.count) 字节")
    }

    // MARK: - 消息发送和接收

    private func sendMessage(event: EventCode, payload: [String: Any]) async throws {
        guard let webSocketTask = webSocketTask else {
            throw TTSError.connectionFailed
        }

        print("📤 发送消息: Event \(event.rawValue)")
        print("   Payload: \(payload)")

        // 将payload转换为JSON
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        let payloadSize = UInt32(jsonData.count)

        print("   JSON size: \(payloadSize) 字节")

        // 构建二进制帧
        var frame = Data()

        // Header (4字节)
        frame.append(0x11)
        frame.append(0x14)
        frame.append(0x10)
        frame.append(0x00)

        // Event number (4字节, big-endian)
        var eventValue = event.rawValue.bigEndian
        frame.append(Data(bytes: &eventValue, count: 4))

        // Payload size (4字节, big-endian)
        var sizeValue = payloadSize.bigEndian
        frame.append(Data(bytes: &sizeValue, count: 4))

        // Payload
        frame.append(jsonData)

        print("   总帧大小: \(frame.count) 字节")

        let message = URLSessionWebSocketTask.Message.data(frame)
        try await webSocketTask.send(message)
        print("   ✅ 已发送")
    }

    private func sendSessionMessage(event: EventCode, sessionId: Data, payload: [String: Any]) async throws {
        guard let webSocketTask = webSocketTask else {
            throw TTSError.connectionFailed
        }

        print("📤 发送会话消息: Event \(event.rawValue)")
        print("   Session ID: \(String(data: sessionId, encoding: .utf8) ?? "?")")

        // 将payload转换为JSON
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        let payloadSize = UInt32(jsonData.count)
        let sessionIdSize = UInt32(sessionId.count)

        // 构建二进制帧
        var frame = Data()

        // Header (4字节)
        frame.append(0x11)
        frame.append(0x14)
        frame.append(0x10)
        frame.append(0x00)

        // Event number (4字节, big-endian)
        var eventValue = event.rawValue.bigEndian
        frame.append(Data(bytes: &eventValue, count: 4))

        // Session ID length (4字节, big-endian)
        var sessionIdSizeValue = sessionIdSize.bigEndian
        frame.append(Data(bytes: &sessionIdSizeValue, count: 4))

        // Session ID
        frame.append(sessionId)

        // Payload size (4字节, big-endian)
        var sizeValue = payloadSize.bigEndian
        frame.append(Data(bytes: &sizeValue, count: 4))

        // Payload
        frame.append(jsonData)

        print("   总帧大小: \(frame.count) 字节")

        let message = URLSessionWebSocketTask.Message.data(frame)
        try await webSocketTask.send(message)
        print("   ✅ 已发送")
    }

    private func waitForEvent(event: EventCode) async throws {
        guard let webSocketTask = webSocketTask else {
            throw TTSError.connectionFailed
        }

        while true {
            let message = try await webSocketTask.receive()

            switch message {
            case .data(let data):
                let (receivedEvent, payload) = try parseMessage(data)

                if receivedEvent == .error {
                    if let errorMsg = payload["message"] as? String {
                        throw TTSError.apiError(errorMsg)
                    }
                    throw TTSError.apiError("未知错误")
                }

                if receivedEvent == event {
                    return
                }

            case .string(let text):
                print("⚠️ 收到文本消息: \(text)")
            @unknown default:
                break
            }
        }
    }

    private func receiveAudioUntilFinished() async throws {
        guard let webSocketTask = webSocketTask else {
            throw TTSError.connectionFailed
        }

        while true {
            let message = try await webSocketTask.receive()

            switch message {
            case .data(let data):
                let (event, payload) = try parseMessage(data)

                if event == .error {
                    if let errorMsg = payload["message"] as? String {
                        throw TTSError.apiError(errorMsg)
                    }
                    throw TTSError.apiError("未知错误")
                }

                switch event {
                case .ttsSentenceStart:
                    print("📝 句子开始")
                case .ttsSentenceEnd:
                    print("📝 句子结束")
                case .ttsResponse:
                    // 提取音频数据（二进制格式）
                    if let audioBinary = payload["audio_binary"] as? Data {
                        audioDataBuffer.append(audioBinary)
                        print("📦 接收音频数据: \(audioBinary.count) 字节")
                    }
                case .sessionFinished:
                    print("✅ 收到SessionFinished")
                    return
                default:
                    print("⚠️ 收到其他事件: \(event)")
                }

            case .string(let text):
                print("⚠️ 收到文本消息: \(text)")
            @unknown default:
                break
            }
        }
    }

    private func parseMessage(_ data: Data) throws -> (EventCode, [String: Any]) {
        print("📥 收到数据: \(data.count) 字节")
        print("   前16字节: \(data.prefix(16).map { String(format: "%02x", $0) }.joined(separator: " "))")

        guard data.count >= 12 else {
            print("❌ 数据太短: \(data.count) < 12")
            throw TTSError.invalidResponse
        }

        // 解析Header (4字节)
        let byte0 = data[0]
        let byte1 = data[1]
        let byte2 = data[2]
        let byte3 = data[3]

        print("   Header: \(String(format: "%02x %02x %02x %02x", byte0, byte1, byte2, byte3))")

        // 检查是否是错误消息 (byte1 = 0xf0)
        if byte1 == 0xf0 {
            print("   ⚠️ 这是错误消息")
            let errorCodeBytes = data[4..<8]
            let errorCode = errorCodeBytes.withUnsafeBytes { $0.load(as: Int32.self).bigEndian }

            let sizeBytes = data[8..<12]
            let payloadSize = sizeBytes.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

            var payload: [String: Any] = [:]
            if payloadSize > 0 && data.count >= 12 + Int(payloadSize) {
                let payloadData = data[12..<(12 + Int(payloadSize))]
                if let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] {
                    payload = json
                    print("   错误信息: \(json)")
                    if let errorMsg = json["error"] as? String {
                        throw TTSError.apiError(errorMsg)
                    }
                }
            }
            throw TTSError.apiError("未知错误，错误码: \(errorCode)")
        }

        // 检查是否是Audio-only response (byte1 = 0xb4)
        if byte1 == 0xb4 {
            print("   🎵 这是音频数据")
            // Audio-only response: Header + Event + SessionID length + SessionID + Audio length + Audio data
            let eventBytes = data[4..<8]
            let eventValue = eventBytes.withUnsafeBytes { $0.load(as: Int32.self).bigEndian }

            guard let event = EventCode(rawValue: eventValue) else {
                print("❌ 未知事件码: \(eventValue)")
                throw TTSError.invalidResponse
            }

            // 跳过 session_id
            let sessionIdLenBytes = data[8..<12]
            let sessionIdLen = sessionIdLenBytes.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            let audioStart = 12 + Int(sessionIdLen)

            guard data.count >= audioStart + 4 else {
                throw TTSError.invalidResponse
            }

            // 读取音频数据长度
            let audioLenBytes = data[audioStart..<(audioStart + 4)]
            let audioLen = audioLenBytes.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

            print("   音频长度: \(audioLen) 字节")

            // 提取音频数据
            if data.count >= audioStart + 4 + Int(audioLen) {
                let audioData = data[(audioStart + 4)..<(audioStart + 4 + Int(audioLen))]
                return (event, ["audio_binary": audioData])
            }

            return (event, [:])
        }

        // 解析Event number (4字节, big-endian)
        let eventBytes = data[4..<8]
        let eventValue = eventBytes.withUnsafeBytes { $0.load(as: Int32.self).bigEndian }

        print("   Event code: \(eventValue)")

        guard let event = EventCode(rawValue: eventValue) else {
            print("❌ 未知事件码: \(eventValue)")
            if data.count > 12 {
                let sizeBytes = data[8..<12]
                let payloadSize = sizeBytes.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
                if payloadSize > 0 && data.count >= 12 + Int(payloadSize) {
                    let payloadData = data[12..<(12 + Int(payloadSize))]
                    if let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] {
                        print("   Payload: \(json)")
                    }
                }
            }
            throw TTSError.invalidResponse
        }

        // 对于有session_id的消息，需要跳过session_id
        var payloadStart = 12
        if event == .sessionStarted || event == .sessionFinished || event == .ttsSentenceStart || event == .ttsSentenceEnd {
            // 这些消息包含session_id
            let sessionIdLenBytes = data[8..<12]
            let sessionIdLen = sessionIdLenBytes.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            payloadStart = 12 + Int(sessionIdLen)

            guard data.count >= payloadStart + 4 else {
                return (event, [:])
            }
        }

        // 解析Payload size
        let sizeBytes = data[payloadStart..<(payloadStart + 4)]
        let payloadSize = sizeBytes.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

        print("   Payload size: \(payloadSize)")

        // 解析Payload
        var payload: [String: Any] = [:]
        if payloadSize > 0 && data.count >= payloadStart + 4 + Int(payloadSize) {
            let payloadData = data[(payloadStart + 4)..<(payloadStart + 4 + Int(payloadSize))]
            if let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] {
                payload = json
                print("   Payload: \(json)")
            }
        }

        return (event, payload)
    }
}

// MARK: - URLSessionWebSocketDelegate

extension VolcengineBidirectionalTTS: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("✅ WebSocket已打开")
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("⚠️ WebSocket已关闭: \(closeCode)")
    }
}
