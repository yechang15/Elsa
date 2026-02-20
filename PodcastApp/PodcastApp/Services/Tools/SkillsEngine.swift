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
        print("🎯 [SkillsEngine] 执行场景: \(scene.rawValue)")
        print("📋 [SkillsEngine] 已注册工具: \(toolRegistry.keys.sorted())")

        let matchedSkills = skills(for: scene)
        guard !matchedSkills.isEmpty else {
            print("⚠️ [SkillsEngine] 场景 \(scene.rawValue) 没有匹配的 Skill")
            return ""
        }

        print("✅ [SkillsEngine] 匹配到 \(matchedSkills.count) 个 Skill: \(matchedSkills.map { $0.id })")

        var contextParts: [String] = []

        for skill in matchedSkills where skill.enabled {
            print("🔧 [SkillsEngine] 执行 Skill: \(skill.id)")
            let result = await executeSkill(skill)
            if !result.isEmpty {
                contextParts.append(result)
                print("✅ [SkillsEngine] Skill \(skill.id) 返回 \(result.count) 字符")
            } else {
                print("⚠️ [SkillsEngine] Skill \(skill.id) 返回空结果")
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
            print("🔍 [SkillsEngine] 查找工具: \(toolConfig.tool)")
            guard let tool = toolRegistry[toolConfig.tool] else {
                print("❌ [SkillsEngine] 工具 '\(toolConfig.tool)' 未注册 (required: \(toolConfig.required))")
                if toolConfig.required {
                    print("⚠️ [SkillsEngine] 必需工具 '\(toolConfig.tool)' 未注册，跳过 Skill: \(skill.id)")
                    return ""
                }
                continue
            }

            let params = toolConfig.params.mapValues { $0.value }
            print("⚙️ [SkillsEngine] 执行工具 '\(toolConfig.tool)' with params: \(params)")
            do {
                let output = try await tool.execute(params: params)
                print("✅ [SkillsEngine] 工具 '\(toolConfig.tool)' 成功，输出: \(output.prefix(100))...")
                results.append((tool: toolConfig.tool, output: output))
            } catch {
                print("❌ [SkillsEngine] 工具 '\(toolConfig.tool)' 执行失败: \(error)")
                if toolConfig.required { return "" }
            }
        }

        let merged = merge(results: results, policy: skill.mergePolicy, skillName: skill.name)
        print("📦 [SkillsEngine] 合并结果: \(merged.count) 字符")
        return merged
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
            // P0: 生成时情境上下文（仅 RSS）
            SkillConfig(
                id: "context_for_generation",
                name: "生成时情境上下文",
                description: "在用户请求生成播客时，拉取日历、天气、RSS 内容供生成脚本参考",
                triggers: [.podcastGenerate, .podcastRecommend],
                tools: [
                    SkillToolConfig(
                        tool: "calendar",
                        params: ["range": AnyCodable("today")],
                        required: false
                    ),
                    SkillToolConfig(
                        tool: "weather",
                        params: ["range": AnyCodable("today")],
                        required: false
                    ),
                    SkillToolConfig(
                        tool: "rss",
                        params: ["range": AnyCodable("latest"), "limit": AnyCodable(10)],
                        required: false
                    )
                ],
                mergePolicy: .concatSummary,
                outputTo: [.promptContext],
                enabled: true
            ),

            // P1: 晨间简报
            SkillConfig(
                id: "morning_briefing",
                name: "晨间简报",
                description: "早晨定时生成包含天气、日程、新闻的播客简报",
                triggers: [.scheduled, .manual],
                tools: [
                    SkillToolConfig(
                        tool: "weather",
                        params: ["range": AnyCodable("today")],
                        required: false
                    ),
                    SkillToolConfig(
                        tool: "calendar",
                        params: ["range": AnyCodable("today")],
                        required: false
                    ),
                    SkillToolConfig(
                        tool: "rss",
                        params: ["range": AnyCodable("latest"), "limit": AnyCodable(5)],
                        required: true
                    )
                ],
                mergePolicy: .structuredBriefing,
                outputTo: [.podcastGenerate],
                enabled: true
            )
        ]
    }
}
