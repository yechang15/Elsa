import Foundation

/// LLM服务 - 支持豆包和OpenAI
class LLMService {
    private let apiKey: String
    private let provider: LLMProvider
    private let model: String

    init(apiKey: String, provider: LLMProvider, model: String) {
        self.apiKey = apiKey
        self.provider = provider
        self.model = model
    }

    /// 生成播客脚本
    func generatePodcastScript(
        articles: [RSSArticle],
        topics: [String],
        length: Int,
        style: String,
        depth: String
    ) async throws -> String {
        let prompt = buildPrompt(articles: articles, topics: topics, length: length, style: style, depth: depth)

        switch provider {
        case .doubao:
            return try await callDoubaoAPI(prompt: prompt)
        case .openai:
            return try await callOpenAIAPI(prompt: prompt)
        }
    }

    /// 构建提示词
    private func buildPrompt(articles: [RSSArticle], topics: [String], length: Int, style: String, depth: String) -> String {
        let articlesText = articles.prefix(5).map { article in
            """
            标题：\(article.title)
            内容：\(article.content.prefix(500))
            """
        }.joined(separator: "\n\n")

        return """
        你是一个播客脚本生成助手。请根据以下RSS文章内容，生成一个\(length)分钟的二人对话式播客脚本。

        话题：\(topics.joined(separator: "、"))
        风格：\(style)
        深度：\(depth)

        RSS文章内容：
        \(articlesText)

        要求：
        1. 生成两个主播（主播A和主播B）的对话
        2. 对话要自然、有趣，符合\(style)的风格
        3. 内容深度符合\(depth)的要求
        4. 时长约\(length)分钟（约\(length * 150)字）
        5. 格式：每行一个对话，格式为"主播A：内容"或"主播B：内容"

        请直接输出播客脚本，不要有其他说明文字。
        """
    }

    /// 调用豆包API
    private func callDoubaoAPI(prompt: String) async throws -> String {
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

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LLMError.apiError("API请求失败")
        }

        let result = try JSONDecoder().decode(DoubaoResponse.self, from: data)
        return result.choices.first?.message.content ?? ""
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

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LLMError.apiError("API请求失败")
        }

        let result = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        return result.choices.first?.message.content ?? ""
    }
}

/// LLM提供商
enum LLMProvider: String, Codable {
    case doubao = "豆包"
    case openai = "OpenAI"
}

/// 豆包API响应
struct DoubaoResponse: Codable {
    let choices: [DoubaoChoice]
}

struct DoubaoChoice: Codable {
    let message: DoubaoMessage
}

struct DoubaoMessage: Codable {
    let content: String
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
