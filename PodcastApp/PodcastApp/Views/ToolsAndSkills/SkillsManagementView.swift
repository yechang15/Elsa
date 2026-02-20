import SwiftUI

struct SkillsManagementView: View {
    @StateObject private var viewModel = SkillsViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                Text("技能（Skills）")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button(action: {
                    // TODO: 新建技能
                }) {
                    Label("新建技能", systemImage: "plus")
                }
                .disabled(true)  // P2 暂不支持新建
            }
            .padding()

            Divider()

            // Skills 列表
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(viewModel.skills) { skill in
                        SkillCard(skill: skill, viewModel: viewModel)
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - SkillCard

struct SkillCard: View {
    let skill: SkillDisplayInfo
    @ObservedObject var viewModel: SkillsViewModel
    @State private var showingEditor = false
    @State private var editingSkill: SkillDisplayInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack {
                Circle()
                    .fill(skill.enabled ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)

                Text(skill.name)
                    .font(.headline)

                Spacer()

                Toggle("", isOn: Binding(
                    get: { skill.enabled },
                    set: { viewModel.toggleSkill(id: skill.id, enabled: $0) }
                ))
                .labelsHidden()
            }

            // 描述
            if !skill.description.isEmpty {
                Text(skill.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 触发场景
            HStack {
                Text("触发：")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(skill.triggersDescription)
                    .font(.caption)
            }

            // 使用的工具
            HStack {
                ForEach(skill.tools, id: \.self) { tool in
                    Text(tool)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
            }

            // 输出目标
            HStack {
                Text("→")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(skill.outputDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 操作按钮
            HStack {
                Button("编辑") {
                    editingSkill = skill
                    showingEditor = true
                }
                .buttonStyle(.bordered)

                Button("▶ 测试运行") {
                    // TODO: 测试运行 Skill
                }
                .buttonStyle(.bordered)
                .disabled(true)  // P2 暂不支持测试
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .opacity(skill.enabled ? 1.0 : 0.6)
        .sheet(isPresented: $showingEditor) {
            if let editingSkill = editingSkill {
                SkillEditorSheet(
                    skill: Binding(
                        get: { editingSkill },
                        set: { self.editingSkill = $0 }
                    ),
                    onSave: { updated in
                        viewModel.updateSkill(updated)
                    }
                )
            }
        }
    }
}

#Preview {
    SkillsManagementView()
        .frame(width: 800, height: 600)
}
