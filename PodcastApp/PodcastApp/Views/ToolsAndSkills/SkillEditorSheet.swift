import SwiftUI

struct SkillEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var skill: SkillDisplayInfo
    let onSave: (SkillDisplayInfo) -> Void

    @State private var editedName: String
    @State private var editedDescription: String
    @State private var editedEnabled: Bool

    init(skill: Binding<SkillDisplayInfo>, onSave: @escaping (SkillDisplayInfo) -> Void) {
        self._skill = skill
        self.onSave = onSave
        self._editedName = State(initialValue: skill.wrappedValue.name)
        self._editedDescription = State(initialValue: skill.wrappedValue.description)
        self._editedEnabled = State(initialValue: skill.wrappedValue.enabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标题栏
            HStack {
                Text("编辑技能")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("取消") {
                    dismiss()
                }
                Button("保存") {
                    saveChanges()
                }
                .buttonStyle(.borderedProminent)
            }

            Divider()

            // 编辑表单
            Form {
                Section("基本信息") {
                    TextField("名称", text: $editedName)
                    TextField("描述", text: $editedDescription, axis: .vertical)
                        .lineLimit(3...6)
                    Toggle("启用", isOn: $editedEnabled)
                }

                Section("触发场景") {
                    Text(skill.triggersDescription)
                        .foregroundColor(.secondary)
                    Text("💡 触发场景暂不支持编辑")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("使用的工具") {
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
                    Text("💡 工具列表暂不支持编辑")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("输出目标") {
                    Text(skill.outputDescription)
                        .foregroundColor(.secondary)
                    Text("💡 输出目标暂不支持编辑")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)
        }
        .padding()
        .frame(width: 600, height: 600)
    }

    private func saveChanges() {
        var updated = skill
        updated.name = editedName
        updated.description = editedDescription
        updated.enabled = editedEnabled
        onSave(updated)
        dismiss()
    }
}

#Preview {
    SkillEditorSheet(
        skill: .constant(SkillDisplayInfo(
            id: "test",
            name: "测试技能",
            description: "这是一个测试技能",
            triggersDescription: "manual",
            tools: ["calendar", "weather"],
            outputDescription: "podcast",
            enabled: true
        )),
        onSave: { _ in }
    )
}
