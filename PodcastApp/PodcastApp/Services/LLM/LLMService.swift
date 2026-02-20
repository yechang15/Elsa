import Foundation

/// 播客类型
enum PodcastType {
    case systemRecommended  // 系统推荐（综合多个话题）
    case topicSpecific      // 话题专属（单个话题）
}

/// LLM服务 - 支持豆包和OpenAI
class LLMService {
    private let apiKey: String
    private let provider: LLMProvider
    private let model: String
    private let urlSession: URLSession

    init(apiKey: String, provider: LLMProvider, model: String) {
        self.apiKey = apiKey
        self.provider = provider
        self.model = model

        // 配置 URLSession，增加超时时间
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 180 // 3分钟
        config.timeoutIntervalForResource = 600 // 10分钟
        config.waitsForConnectivity = true // 等待网络连接

        // 禁用代理，避免代理连接失败的问题
        config.connectionProxyDictionary = [:]

        self.urlSession = URLSession(configuration: config)
    }

    /// 生成播客脚本
    func generatePodcastScript(
        articles: [RSSArticle],
        topics: [String],
        length: Int,
        style: String,
        depth: String,
        hostAName: String = "主播A",
        hostBName: String = "主播B",
        podcastType: PodcastType = .systemRecommended,
        frequency: String? = nil,
        userMemory: String? = nil,
        contextFromSkills: String? = nil,
        progressHandler: ((String) -> Void)? = nil
    ) async throws -> String {
        let prompt = buildPrompt(
            articles: articles,
            topics: topics,
            length: length,
            style: style,
            depth: depth,
            hostAName: hostAName,
            hostBName: hostBName,
            podcastType: podcastType,
            frequency: frequency,
            userMemory: userMemory,
            contextFromSkills: contextFromSkills
        )

        print("\n========== [LLM Prompt] ==========\n\(prompt)\n==================================\n")

        switch provider {
        case .doubao:
            return try await callDoubaoAPIStreaming(prompt: prompt, progressHandler: progressHandler)
        case .openai:
            return try await callOpenAIAPIStreaming(prompt: prompt, progressHandler: progressHandler)
        }
    }

    /// 生成文本（通用方法，用于记忆摘要等）
    func generateText(prompt: String) async throws -> String {
        switch provider {
        case .doubao:
            return try await callDoubaoAPIStreaming(prompt: prompt, progressHandler: nil)
        case .openai:
            return try await callOpenAIAPIStreaming(prompt: prompt, progressHandler: nil)
        }
    }

    /// 构建提示词
    private func buildPrompt(
        articles: [RSSArticle],
        topics: [String],
        length: Int,
        style: String,
        depth: String,
        hostAName: String,
        hostBName: String,
        podcastType: PodcastType,
        frequency: String?,
        userMemory: String?,
        contextFromSkills: String?
    ) -> String {
        let articlesText = articles.prefix(5).map { article in
            """
            标题：\(article.title)
            内容：\(article.content.prefix(500))
            """
        }.joined(separator: "\n\n")

        // 根据播客类型生成上下文说明
        let contextDescription: String
        switch podcastType {
        case .systemRecommended:
            if let freq = frequency {
                contextDescription = "这是一期综合多个话题的播客节目，\(freq)更新一次。"
            } else {
                contextDescription = "这是一期综合多个话题的播客节目。"
            }
        case .topicSpecific:
            if let freq = frequency {
                contextDescription = "这是一期专注于「\(topics.first ?? "")」话题的播客节目，\(freq)更新一次。"
            } else {
                contextDescription = "这是一期专注于「\(topics.first ?? "")」话题的播客节目。"
            }
        }

        // 构建用户记忆部分
        let memorySection: String
        if let memory = userMemory, !memory.isEmpty {
            memorySection = """

            【用户偏好记忆】
            \(memory)

            请根据以上用户偏好，调整播客的话题选择、内容深度、对话风格和节奏。
            """
        } else {
            memorySection = ""
        }

        // 构建情境上下文部分（来自 Skills）
        let contextSection: String
        if let context = contextFromSkills, !context.isEmpty {
            contextSection = """

            【情境上下文】
            \(context)

            以上是通过工具获取的实时情境信息，可作为播客内容的补充素材或开场参考。
            """
        } else {
            contextSection = ""
        }

        return """
        你是一个播客脚本生成助手。请根据以下RSS文章内容，生成一个\(length)分钟的二人对话式播客脚本。

        播客定位：\(contextDescription)
        话题：\(topics.joined(separator: "、"))
        风格：\(style)
        深度：\(depth)\(memorySection)\(contextSection)

        RSS文章内容：
        \(articlesText)

        要求：
        1. 生成两个主播（\(hostAName)和\(hostBName)）的对话
        2. 对话要自然、有趣，符合\(style)的风格
        3. 内容深度符合\(depth)的要求
        4. 时长约\(length)分钟（约\(length * 150)字）
        5. 格式：每行一个对话，格式为"\(hostAName)：内容"或"\(hostBName)：内容"
        6. 主播在介绍自己时，直接说"我是\(hostAName)"或"我是\(hostBName)"，不要说"我是主播A"或"我是主播B"
        7. 开场白要准确反映播客的更新频率和定位，不要说"每周"等不准确的描述
        8. 如果是话题专属播客，要突出该话题的特色，不要泛泛而谈

        请直接输出播客脚本，不要有其他说明文字。
        """
    }

    /// 调用豆包API
    private func callDoubaoAPI(prompt: String) async throws -> String {
        print("开始调用豆包API...")
        print("API Key 长度: \(apiKey.count)")
        print("模型: \(model)")

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
                            "text": prompt
                        ]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("发送请求到豆包API...")
        let startTime = Date()

        let (data, response) = try await urlSession.data(for: request)

        let duration = Date().timeIntervalSince(startTime)
        print("豆包API响应时间: \(duration)秒")

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            // 打印错误信息以便调试
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            if let errorString = String(data: data, encoding: .utf8) {
                print("豆包API错误 (状态码: \(statusCode)): \(errorString)")
            }

            // 根据状态码提供更详细的错误信息
            let errorMessage: String
            switch statusCode {
            case 401:
                errorMessage = "API Key 无效或未授权，请检查设置中的 API Key 配置"
            case 403:
                errorMessage = "API 访问被拒绝，请检查 API Key 权限"
            case 429:
                errorMessage = "API 请求频率超限，请稍后再试"
            case 500...599:
                errorMessage = "API 服务器错误，请稍后再试"
            default:
                errorMessage = "API 请求失败，状态码: \(statusCode)"
            }

            throw LLMError.apiError(errorMessage)
        }

        let result = try JSONDecoder().decode(DoubaoResponse.self, from: data)

        // 从 output 数组中找到 type 为 "message" 的项
        guard let messageOutput = result.output?.first(where: { $0.type == "message" }),
              let textContent = messageOutput.content?.first(where: { $0.type == "output_text" }),
              let text = textContent.text else {
            throw LLMError.invalidResponse
        }

        return text
    }

    /// 调用豆包API（流式）
    private func callDoubaoAPIStreaming(prompt: String, progressHandler: ((String) -> Void)?) async throws -> String {
        print("开始调用豆包API（流式）...")
        print("API Key 长度: \(apiKey.count)")
        print("模型: \(model)")

        let url = URL(string: "https://ark.cn-beijing.volces.com/api/v3/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "stream": true
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("发送流式请求到豆包API...")
        let startTime = Date()

        var fullText = ""
        var lastUpdateTime = Date()

        let (bytes, response) = try await urlSession.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw LLMError.apiError("API 请求失败，状态码: \(statusCode)")
        }

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let data = line.dropFirst(6)

            if data == "[DONE]" { break }

            guard let jsonData = data.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let content = delta["content"] as? String else {
                continue
            }

            fullText += content

            // 每0.5秒更新一次进度
            if Date().timeIntervalSince(lastUpdateTime) > 0.5 {
                progressHandler?("已生成 \(fullText.count) 字符...")
                lastUpdateTime = Date()
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        print("豆包API流式响应完成，耗时: \(duration)秒")
        progressHandler?("脚本生成完成！")

        return fullText
    }

    /// 调用OpenAI API（流式）
    private func callOpenAIAPIStreaming(prompt: String, progressHandler: ((String) -> Void)?) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "stream": true
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        var fullText = ""
        var lastUpdateTime = Date()

        let (bytes, response) = try await urlSession.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw LLMError.apiError("OpenAI API 请求失败，状态码: \(statusCode)")
        }

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let data = line.dropFirst(6)

            if data == "[DONE]" { break }

            guard let jsonData = data.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let content = delta["content"] as? String else {
                continue
            }

            fullText += content

            if Date().timeIntervalSince(lastUpdateTime) > 0.5 {
                progressHandler?("已生成 \(fullText.count) 字符...")
                lastUpdateTime = Date()
            }
        }

        progressHandler?("脚本生成完成！")
        return fullText
    }

    /// 调用OpenAI API
    private func callOpenAIAPI(prompt: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            if let errorString = String(data: data, encoding: .utf8) {
                print("OpenAI API错误 (状态码: \(statusCode)): \(errorString)")
            }

            let errorMessage: String
            switch statusCode {
            case 401:
                errorMessage = "OpenAI API Key 无效或未授权"
            case 429:
                errorMessage = "OpenAI API 请求频率超限"
            case 500...599:
                errorMessage = "OpenAI 服务器错误"
            default:
                errorMessage = "OpenAI API 请求失败，状态码: \(statusCode)"
            }

            throw LLMError.apiError(errorMessage)
        }

        let result = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        return result.choices.first?.message.content ?? ""
    }

    /// 通用对话方法（用于聊天功能）- 流式版本
    func chatStreaming(prompt: String, progressHandler: ((String) -> Void)?) async throws -> String {
        switch provider {
        case .doubao:
            return try await chatWithDoubaoStreaming(prompt: prompt, progressHandler: progressHandler)
        case .openai:
            return try await chatWithOpenAIStreaming(prompt: prompt, progressHandler: progressHandler)
        }
    }

    /// 与豆包对话（流式）
    private func chatWithDoubaoStreaming(prompt: String, progressHandler: ((String) -> Void)?) async throws -> String {
        let url = URL(string: "https://ark.cn-beijing.volces.com/api/v3/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "stream": true
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        var fullText = ""
        let (bytes, response) = try await urlSession.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw LLMError.apiError("API 请求失败，状态码: \(statusCode)")
        }

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let data = line.dropFirst(6)

            if data == "[DONE]" { break }

            guard let jsonData = data.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let content = delta["content"] as? String else {
                continue
            }

            fullText += content
            progressHandler?(fullText)
        }

        return fullText
    }

    /// 与OpenAI对话（流式）
    private func chatWithOpenAIStreaming(prompt: String, progressHandler: ((String) -> Void)?) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "stream": true
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        var fullText = ""
        let (bytes, response) = try await urlSession.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw LLMError.apiError("OpenAI API 请求失败，状态码: \(statusCode)")
        }

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let data = line.dropFirst(6)

            if data == "[DONE]" { break }

            guard let jsonData = data.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let content = delta["content"] as? String else {
                continue
            }

            fullText += content
            progressHandler?(fullText)
        }

        return fullText
    }

    /// 通用对话方法（用于聊天功能）
    func chat(prompt: String) async throws -> String {
        switch provider {
        case .doubao:
            return try await chatWithDoubao(prompt: prompt)
        case .openai:
            return try await chatWithOpenAI(prompt: prompt)
        }
    }

    /// 与豆包对话
    private func chatWithDoubao(prompt: String) async throws -> String {
        let url = URL(string: "https://ark.cn-beijing.volces.com/api/v3/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw LLMError.apiError("API 请求失败，状态码: \(statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.invalidResponse
        }

        return content
    }

    /// 与OpenAI对话
    private func chatWithOpenAI(prompt: String) async throws -> String {
        return try await callOpenAIAPI(prompt: prompt)
    }
}

/// LLM提供商
enum LLMProvider: String, Codable {
    case doubao = "豆包"
    case openai = "OpenAI"
}

/// 豆包API响应
struct DoubaoResponse: Codable {
    let output: [DoubaoOutputItem]?
}

struct DoubaoOutputItem: Codable {
    let type: String
    let role: String?
    let content: [DoubaoContent]?
}

struct DoubaoContent: Codable {
    let type: String
    let text: String?
}

/// OpenAI API响应
struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]
}

struct OpenAIChoice: Codable {
    let message: OpenAIMessage
}

struct OpenAIMessage: Codable {
    let content: String
}

/// LLM错误
enum LLMError: LocalizedError {
    case apiError(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .apiError(let message):
            return "API错误: \(message)"
        case .invalidResponse:
            return "无效的响应"
        }
    }
}
