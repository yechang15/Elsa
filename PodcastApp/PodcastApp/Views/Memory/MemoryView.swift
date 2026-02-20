import SwiftUI
import SwiftData

struct MemoryView: View {
    @EnvironmentObject var memoryManager: MemoryManager
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var podcastService: PodcastService
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

            // 描述信息
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedTab.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

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
                try memoryManager.updatePreferences(content)

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
                // 确保 LLM 服务已注入
                if memoryManager.llmService == nil {
                    // 从 PodcastService 获取并注入
                    await MainActor.run {
                        podcastService.setupLLM(
                            apiKey: appState.userConfig.llmApiKey,
                            provider: appState.userConfig.llmProvider == "豆包" ? .doubao : .openai,
                            model: appState.userConfig.llmModel
                        )
                    }
                    // 等待异步注入完成
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                }

                print("🔄 开始生成摘要...")
                let content = try await memoryManager.generateSummary()
                print("✅ 摘要生成完成，长度: \(content.count) 字符")
                print("📝 摘要内容预览: \(content.prefix(200))...")

                try memoryManager.updateSummary(content)
                print("💾 摘要已保存")

                await MainActor.run {
                    isGenerating = false
                    alertMessage = "摘要已生成\n长度: \(content.count) 字符"
                    showAlert = true
                    selectedTab = .summary // 触发刷新
                }
            } catch {
                print("❌ 生成摘要失败: \(error)")
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
                try memoryManager.saveMemory(selectedTab, content: editingContent)
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

    var description: String {
        switch self {
        case .summary:
            return "📝 从其他 3 个记忆文件智能压缩生成（300字内），生成播客时自动注入到 AI prompt"
        case .preferences:
            return "🎯 从你的播放行为和订阅话题分析得出，每10次播放自动更新，用于个性化推荐"
        case .profile:
            return "👤 从聊天对话中提取的长期特征（职业、性格、沟通风格等），每10条对话自动分析"
        case .goals:
            return "🎓 从聊天对话中提取的当前目标（学习、职业、短期需求等），帮助生成对你有用的内容"
        }
    }
}
