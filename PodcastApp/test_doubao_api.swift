#!/usr/bin/env swift

import Foundation

// 测试豆包 API 连接
func testDoubaoAPI() async {
    let apiKey = "66117f6b-b659-4a84-9e5e-c4630ee1b248"
    let model = "doubao-seed-2-0-pro-260215"
    let url = URL(string: "https://ark.cn-beijing.volces.com/api/v3/responses")!

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let body: [String: Any] = [
        "model": model,
        "input": [
            [
                "role": "user",
                "content": [
                    [
                        "type": "input_text",
                        "text": "请生成一个简短的播客脚本，主题是Swift编程，包含主播A和主播B的对话，约50字。"
                    ]
                ]
            ]
        ]
    ]

    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            print("状态码: \(httpResponse.statusCode)")
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            print("\n完整响应:")
            print(json)

            // 解析 output
            if let output = json["output"] as? [[String: Any]] {
                print("\n找到 \(output.count) 个 output 项")

                for (index, item) in output.enumerated() {
                    print("\nOutput [\(index)]:")
                    print("  type: \(item["type"] ?? "unknown")")

                    if let content = item["content"] as? [[String: Any]] {
                        for contentItem in content {
                            if let type = contentItem["type"] as? String,
                               type == "output_text",
                               let text = contentItem["text"] as? String {
                                print("\n✅ 提取到的文本:")
                                print(text)
                            }
                        }
                    }
                }
            }
        }

    } catch {
        print("❌ 错误: \(error)")
    }
}

// 运行测试
Task {
    await testDoubaoAPI()
    exit(0)
}

RunLoop.main.run()
