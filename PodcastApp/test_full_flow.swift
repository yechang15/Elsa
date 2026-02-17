import Foundation

print("=== 完整流程测试 ===\n")

class FullTest: NSObject, URLSessionWebSocketDelegate {
    var task: URLSessionWebSocketTask?
    var audioData = Data()
    var sessionId = ""

    func test() async throws {
        // 1. 连接
        let url = URL(string: "wss://openspeech.bytedance.com/api/v3/tts/bidirection")!
        var request = URLRequest(url: url)
        request.setValue("d79ba916-8a76-4d5e-b9e5-dce9955c973c", forHTTPHeaderField: "X-Api-Key")
        request.setValue("seed-tts-2.0", forHTTPHeaderField: "X-Api-Resource-Id")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Api-Connect-Id")

        print("1️⃣ 建立连接...")
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        task = session.webSocketTask(with: request)
        task?.resume()
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // 2. StartConnection
        print("2️⃣ 发送 StartConnection...")
        try await send(event: 1, payload: [:])
        let (event1, _) = try await receive()
        guard event1 == 50 else { throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "未收到ConnectionStarted"]) }
        print("   ✅ 连接已建立\n")

        // 3. StartSession
        print("3️⃣ 发送 StartSession...")
        sessionId = "test-session"  // 12字节
        let sessionIdData = sessionId.data(using: .utf8)!

        let sessionPayload: [String: Any] = [
            "user": [:],
            "req_params": [
                "text": "",
                "speaker": "zh_female_tianmeixiaoyuan",
                "audio_params": [
                    "format": "mp3",
                    "sample_rate": 24000,
                    "speech_rate": 0
                ]
            ]
        ]

        try await sendSession(event: 100, sessionId: sessionIdData, payload: sessionPayload)
        let (event2, _) = try await receive()
        guard event2 == 150 else { throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "未收到SessionStarted，收到: \(event2)"]) }
        print("   ✅ 会话已开始\n")

        // 4. SendText
        print("4️⃣ 发送文本...")
        try await send(event: 200, payload: [
            "event": 200,
            "namespace": "BidirectionalTTS",
            "req_params": [
                "text": "你好，这是一个测试。"
            ]
        ])
        print("   ✅ 文本已发送\n")

        // 5. FinishSession
        print("5️⃣ 结束会话...")
        try await send(event: 102, payload: [
            "event": 102,
            "namespace": "BidirectionalTTS"
        ])

        // 6. 接收音频
        print("6️⃣ 接收音频数据...")
        var audioCount = 0
        while true {
            let (event, payload) = try await receive()
            if event == 250 { // AudioData
                if let data = payload["data"] as? String, let decoded = Data(base64Encoded: data) {
                    audioData.append(decoded)
                    audioCount += 1
                    print("   📦 音频包 #\(audioCount): \(decoded.count) 字节")
                }
            } else if event == 152 { // SessionFinished
                print("   ✅ 会话结束\n")
                break
            }
        }

        // 7. FinishConnection
        print("7️⃣ 断开连接...")
        try await send(event: 2, payload: [:])
        let (event3, _) = try await receive()
        guard event3 == 52 else { throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "未收到ConnectionFinished"]) }
        print("   ✅ 连接已断开\n")

        // 8. 保存音频
        print("8️⃣ 保存音频...")
        let path = "/tmp/test_full.mp3"
        try audioData.write(to: URL(fileURLWithPath: path))
        print("   💾 已保存: \(path)")
        print("   📊 总大小: \(audioData.count) 字节\n")

        // 9. 播放
        print("9️⃣ 播放音频...")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
        process.arguments = [path]
        try process.run()
        process.waitUntilExit()
        print("   ✅ 播放完成")
    }

    func send(event: Int32, payload: [String: Any]) async throws {
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        let payloadSize = UInt32(jsonData.count)

        var frame = Data()
        frame.append(0x11)
        frame.append(0x14)
        frame.append(0x10)
        frame.append(0x00)

        var eventValue = event.bigEndian
        frame.append(Data(bytes: &eventValue, count: 4))

        var sizeValue = payloadSize.bigEndian
        frame.append(Data(bytes: &sizeValue, count: 4))

        frame.append(jsonData)

        print("   📤 发送 \(frame.count) 字节")
        print("      前16字节: \(frame.prefix(16).map { String(format: "%02x", $0) }.joined(separator: " "))")
        print("      Event: \(event), Payload size: \(payloadSize)")
        if let jsonStr = String(data: jsonData, encoding: .utf8) {
            print("      JSON: \(jsonStr.prefix(100))")
        }

        try await task?.send(.data(frame))
    }

    func sendSession(event: Int32, sessionId: Data, payload: [String: Any]) async throws {
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        let payloadSize = UInt32(jsonData.count)
        let sessionIdSize = UInt32(sessionId.count)

        var frame = Data()
        frame.append(0x11)
        frame.append(0x14)
        frame.append(0x10)
        frame.append(0x00)

        // Event number
        var eventValue = event.bigEndian
        frame.append(Data(bytes: &eventValue, count: 4))

        // Session ID length
        var sessionIdSizeValue = sessionIdSize.bigEndian
        frame.append(Data(bytes: &sessionIdSizeValue, count: 4))

        // Session ID
        frame.append(sessionId)

        // Payload size
        var sizeValue = payloadSize.bigEndian
        frame.append(Data(bytes: &sizeValue, count: 4))

        // Payload
        frame.append(jsonData)

        print("   📤 发送 \(frame.count) 字节")
        print("      Session ID: \(String(data: sessionId, encoding: .utf8) ?? "?")")
        print("      Payload size: \(payloadSize)")

        try await task?.send(.data(frame))
    }

    func receive() async throws -> (Int32, [String: Any]) {
        guard let msg = try await task?.receive() else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法接收消息"])
        }

        switch msg {
        case .data(let data):
            print("   📥 收到 \(data.count) 字节")
            print("      前16字节: \(data.prefix(16).map { String(format: "%02x", $0) }.joined(separator: " "))")

            guard data.count >= 12 else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "数据太短"])
            }

            let eventBytes = data[4..<8]
            let eventValue = eventBytes.withUnsafeBytes { $0.load(as: Int32.self).bigEndian }
            print("      Event code: \(eventValue)")

            let sizeBytes = data[8..<12]
            let payloadSize = sizeBytes.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            print("      Payload size: \(payloadSize)")

            var payload: [String: Any] = [:]
            if payloadSize > 0 && data.count >= 12 + Int(payloadSize) {
                let payloadData = data[12..<(12 + Int(payloadSize))]
                if let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] {
                    payload = json
                    print("      Payload: \(json)")
                } else if let text = String(data: payloadData, encoding: .utf8) {
                    print("      Payload (text): \(text)")
                }
            }

            return (eventValue, payload)

        case .string(let text):
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "收到文本: \(text)"])

        @unknown default:
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "未知消息类型"])
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("   ✅ WebSocket已打开\n")
    }
}

Task {
    do {
        try await FullTest().test()
        print("\n🎉 测试完全成功！")
    } catch {
        print("\n❌ 错误: \(error.localizedDescription)")
    }
    exit(0)
}

RunLoop.main.run()
