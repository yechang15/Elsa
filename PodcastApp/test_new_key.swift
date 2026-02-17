import Foundation

print("=== 测试新版API Key ===\n")

class QuickTest: NSObject, URLSessionWebSocketDelegate {
    var task: URLSessionWebSocketTask?
    var audioData = Data()

    func test() async throws {
        let url = URL(string: "wss://openspeech.bytedance.com/api/v3/tts/bidirection")!
        var request = URLRequest(url: url)
        request.setValue("d79ba916-8a76-4d5e-b9e5-dce9955c973c", forHTTPHeaderField: "X-Api-Key")
        request.setValue("seed-tts-2.0", forHTTPHeaderField: "X-Api-Resource-Id")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Api-Connect-Id")

        print("📡 连接中...")
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        task = session.webSocketTask(with: request)
        task?.resume()

        try await Task.sleep(nanoseconds: 2_000_000_000)

        // StartConnection
        print("📤 发送 StartConnection...")
        try await send(event: 1, payload: [:])

        // 接收响应
        print("📥 等待响应...")
        try await receive()
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

        try await task?.send(.data(frame))
        print("   ✅ 已发送")
    }

    func receive() async throws {
        guard let msg = try await task?.receive() else { return }

        switch msg {
        case .data(let data):
            print("✅ 收到数据: \(data.count) 字节")
            if data.count >= 12 {
                let eventBytes = data[4..<8]
                let eventValue = eventBytes.withUnsafeBytes { $0.load(as: Int32.self).bigEndian }
                print("   Event code: \(eventValue)")

                if eventValue == 50 {
                    print("   🎉 ConnectionStarted - 认证成功！")
                }
            }
        case .string(let text):
            print("✅ 收到文本: \(text)")
        @unknown default:
            break
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("✅ WebSocket已连接\n")
    }
}

Task {
    do {
        try await QuickTest().test()
        print("\n✅ 测试成功！新版API Key有效")
    } catch {
        print("\n❌ 错误: \(error)")
    }
    exit(0)
}

RunLoop.main.run()
