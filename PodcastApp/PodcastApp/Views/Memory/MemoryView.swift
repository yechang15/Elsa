import SwiftUI

struct MemoryView: View {
    @EnvironmentObject var memoryManager: MemoryManager
    @State private var selectedTab: MemoryFileType = .summary
    @State private var isGenerating = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isEditing = false
    @State private var editingContent = ""

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("用户记忆管理")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                if let lastUpdate = memoryManager.lastUpdateDate {
                    Text("最后更新: \(lastUpdate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()

            Divider()

            // 标签页选择
            Picker("记忆类型", selection: $selectedTab) {
                Text("摘要").tag(MemoryFileType.summary)
                Text("偏好设置").tag(MemoryFileType.preferences)
                Text("用户画像").tag(MemoryFileType.profile)
                Text("目标").tag(MemoryFileType.goals)
            }
            .pickerStyle(.segmented)
            .padding()

            // 内容区域
            ScrollView {
                if isEditing {
                    // 编辑模式
                    TextEditor(text: $editingContent)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                } else if let content = memoryManager.loadMemory(selectedTab) {
                    Text(content)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text("暂无\(selectedTab.displayName)数据")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        if selectedTab == .preferences {
                            Button("从行为数据生成偏好") {
                                generatePreferences()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                }
            }

            Divider()

            // 底部操作栏
            HStack {
                if isEditing {
                    Button("取消") {
                        isEditing = false
                    }

                    Spacer()

                    Button("保存") {
                        saveEditedContent()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("刷新") {
                        // 触发视图刷新
                        selectedTab = selectedTab
                    }

                    Spacer()

                    if memoryManager.loadMemory(selectedTab) != nil {
                        Button("编辑") {
                            startEditing()
                        }
                    }

                    if selectedTab == .preferences {
                        Button("从行为数据生成") {
                            generatePreferences()
                        }
                        .disabled(isGenerating)
                    }

                    if selectedTab == .summary {
                        Button("生成摘要") {
                            generateSummaryAction()
                        }
                        .disabled(isGenerating)
                    }

                    Button("查看统计") {
                        showMemoryStats()
                    }
                }
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 400)
        .alert("提示", isPresented: $showAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private func generatePreferences() {
        isGenerating = true
        Task {
            do {
                let content = try await memoryManager.generatePreferencesFromBehavior()
                try await memoryManager.updatePreferences(content)

                await MainActor.run {
                    isGenerating = false
                    alertMessage = "偏好设置已生成"
                    showAlert = true
                    selectedTab = .preferences // 触发刷新
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    alertMessage = "生成失败: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }

    private func generateSummaryAction() {
        isGenerating = true
        Task {
            do {
                let content = try await memoryManager.generateSummary()
                try await memoryManager.updateSummary(content)

                await MainActor.run {
                    isGenerating = false
                    let hasLLM = memoryManager.llmService != nil
                    alertMessage = hasLLM ? "摘要已生成（LLM 版本）" : "摘要已生成（基础版本）"
                    showAlert = true
                    selectedTab = .summary // 触发刷新
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    alertMessage = "生成失败: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }

    private func showMemoryStats() {
        let stats = memoryManager.getMemoryStatus()
        let message = """
        记忆文件状态：
        - 用户画像: \(stats["profileExists"] as? Bool == true ? "✓" : "✗")
        - 偏好设置: \(stats["preferencesExists"] as? Bool == true ? "✓" : "✗")
        - 目标: \(stats["goalsExists"] as? Bool == true ? "✓" : "✗")
        - 摘要: \(stats["summaryExists"] as? Bool == true ? "✓" : "✗")

        最后更新: \(stats["lastUpdateDate"] as? String ?? "从未")
        """
        alertMessage = message
        showAlert = true
    }

    private func startEditing() {
        if let content = memoryManager.loadMemory(selectedTab) {
            editingContent = content
            isEditing = true
        }
    }

    private func saveEditedContent() {
        Task {
            do {
                try await memoryManager.saveMemory(selectedTab, content: editingContent)
                await MainActor.run {
                    isEditing = false
                    alertMessage = "\(selectedTab.displayName)已保存"
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    alertMessage = "保存失败: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
}

extension MemoryFileType {
    var displayName: String {
        switch self {
        case .profile: return "用户画像"
        case .preferences: return "偏好设置"
        case .goals: return "目标"
        case .summary: return "摘要"
        }
    }
}
