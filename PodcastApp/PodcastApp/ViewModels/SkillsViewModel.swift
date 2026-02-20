import Foundation

// MARK: - SkillDisplayInfo

/// Skill 显示信息
struct SkillDisplayInfo: Identifiable {
    let id: String
    var name: String
    var description: String
    let triggersDescription: String
    let tools: [String]
    let outputDescription: String
    var enabled: Bool
}

// MARK: - SkillsViewModel

@MainActor
class SkillsViewModel: ObservableObject {
    @Published var skills: [SkillDisplayInfo] = []

    init() {
        loadSkills()
    }

    func loadSkills() {
        // 从 SkillsEngine 加载内置 Skills
        skills = [
            SkillDisplayInfo(
                id: "context_for_generation",
                name: "生成时情境上下文",
                description: "在用户请求生成播客时，拉取日历、天气、RSS 内容供生成脚本参考",
                triggersDescription: "podcast_generate, podcast_recommend",
                tools: ["calendar", "weather", "rss"],
                outputDescription: "prompt_context",
                enabled: true
            ),
            SkillDisplayInfo(
                id: "morning_briefing",
                name: "晨间简报",
                description: "早晨定时生成包含天气、日程、新闻的播客简报",
                triggersDescription: "scheduled, manual",
                tools: ["weather", "calendar", "rss"],
                outputDescription: "podcast_generate",
                enabled: true
            )
        ]
    }

    func toggleSkill(id: String, enabled: Bool) {
        if let index = skills.firstIndex(where: { $0.id == id }) {
            skills[index].enabled = enabled
            // TODO: 持久化到 SkillsEngine
            print("✏️ Skill '\(id)' enabled: \(enabled)")
        }
    }

    func updateSkill(_ updated: SkillDisplayInfo) {
        if let index = skills.firstIndex(where: { $0.id == updated.id }) {
            skills[index] = updated
            // TODO: 持久化到 SkillsEngine
            print("✏️ Skill '\(updated.id)' updated: \(updated.name)")
        }
    }
}
