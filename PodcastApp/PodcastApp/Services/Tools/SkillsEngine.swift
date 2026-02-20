import Foundation

// MARK: - SkillsEngine

/// 编排引擎：根据场景加载匹配的 Skill，调用工具，合并结果
@MainActor
class SkillsEngine: ObservableObject {

    // MARK: - 工具注册表（轻量元数据，按需初始化）
    private(set) var toolRegistry: [String: any AgentTool] = [:]

    // MARK: - Skill 配置缓存（按场景懒加载）
    private var skillCache: [SkillScene: [SkillConfig]] = [:]

    // MARK: - 内置 Skill 配置（P0 阶段直接内嵌，P1 后可改为文件加载）
    private let builtinSkills: [SkillConfig] = SkillsEngine.loadBuiltinSkills()

    // MARK: - 注册工具

    func register(tool: any AgentTool) {
        toolRegistry[tool.name] = tool
    }

    // MARK: - 执行场景

    /// 根据场景执行匹配的 Skills，返回合并后的情境上下文字符串
    func execute(scene: SkillScene) async -> String {
        let matchedSkills = skills(for: scene)
        guard !matchedSkills.isEmpty else { return "" }

        var contextParts: [String] = []

        for skill in matchedSkills where skill.enabled {
            let result = await executeSkill(skill)
            if !result.isEmpty {
                contextParts.append(result)
            }
        }

        return contextParts.joined(separator: "\n\n")
    }

    // MARK: - 私有方法

    private func skills(for scene: SkillScene) -> [SkillConfig] {
        if let cached = skillCache[scene] { return cached }
        let matched = builtinSkills.filter { $0.triggers.contains(scene) }
        skillCache[scene] = matched
        return matched
    }

    private func executeSkill(_ skill: SkillConfig) async -> String {
        var results: [(tool: String, output: String)] = []

        for toolConfig in skill.tools {
            guard let tool = toolRegistry[toolConfig.tool] else {
                if toolConfig.required {
                    print("⚠️ [SkillsEngine] 必需工具 '\(toolConfig.tool)' 未注册，跳过 Skill: \(skill.id)")
                    return ""
                }
                continue
            }

            let params = toolConfig.params.mapValues { $0.value }
            do {
                let output = try await tool.execute(params: params)
                results.append((tool: toolConfig.tool, output: output))
            } catch {
                print("⚠️ [SkillsEngine] 工具 '\(toolConfig.tool)' 执行失败: \(error)")
                if toolConfig.required { return "" }
            }
        }

        return merge(results: results, policy: skill.mergePolicy, skillName: skill.name)
    }

    private func merge(
        results: [(tool: String, output: String)],
        policy: MergePolicy,
        skillName: String
    ) -> String {
        guard !results.isEmpty else { return "" }

        switch policy {
        case .concatSummary:
            let parts = results.map { "【\($0.tool)】\($0.output)" }
            return "=== \(skillName) ===\n" + parts.joined(separator: "\n")

        case .structuredBriefing:
            let parts = results.map { "- \($0.tool): \($0.output)" }
            return "【情境简报】\n" + parts.joined(separator: "\n")

        case .meetingBrief:
            return results.map { $0.output }.joined(separator: "\n")

        case .recommendationScore:
            return results.map { $0.output }.joined(separator: "\n")
        }
    }

    // MARK: - 内置 Skill 定义

    private static func loadBuiltinSkills() -> [SkillConfig] {
        return [
            SkillConfig(
                id: "context_for_generation",
                name: "生成时情境上下文",
                description: "在用户请求生成播客时，拉取 RSS 内容供生成脚本参考",
                triggers: [.podcastGenerate, .podcastRecommend],
                tools: [
                    SkillToolConfig(
                        tool: "rss",
                        params: ["range": AnyCodable("latest"), "limit": AnyCodable(10)],
                        required: false
                    )
                ],
                mergePolicy: .concatSummary,
                outputTo: [.promptContext],
                enabled: true
            )
        ]
    }
}
