import SwiftUI
import SwiftData

// 为特定话题生成播客的Sheet
struct GeneratePodcastSheetForTopic: View {
    let selectedTopic: String

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var podcastService: PodcastService
    @EnvironmentObject var audioPlayer: AudioPlayer

    @Query(sort: \Topic.priority, order: .reverse) private var allTopics: [Topic]

    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var currentStep: GenerationStep = .idle
    @State private var stepProgress: Double = 0.0

    var body: some View {
        VStack(spacing: 20) {
            // 标题
            HStack {
                Text(titleText)
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button("取消") {
                    dismiss()
                }
            }
            .padding()

            Divider()

            if targetTopics.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)

                    Text("还没有话题")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("请先在「兴趣话题」页面添加话题")
                        .foregroundColor(.secondary)

                    Button("去添加话题") {
                        dismiss()
                        appState.selectedNavigation = .topics
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isGenerating {
                // 生成进度显示
                GeneratingProgressView(
                    currentStep: currentStep,
                    stepProgress: stepProgress,
                    currentStatus: podcastService.currentStatus
                )
            } else {
                // 生成配置
                GenerateConfigView(
                    topics: targetTopics,
                    config: appState.userConfig,
                    errorMessage: errorMessage,
                    onGenerate: generatePodcast
                )
            }
        }
        .frame(width: 500, height: 600)
    }

    // 标题文本
    private var titleText: String {
        switch selectedTopic {
        case "推荐", "全部":
            return "生成播客"
        default:
            return "生成「\(selectedTopic)」播客"
        }
    }

    // 目标话题列表
    private var targetTopics: [Topic] {
        if selectedTopic == "推荐" || selectedTopic == "全部" {
            return allTopics
        } else {
            return allTopics.filter { $0.name == selectedTopic }
        }
    }

    private func generatePodcast() {
        isGenerating = true
        errorMessage = nil
        currentStep = .fetchingRSS
        stepProgress = 0.0

        Task {
            do {
                // 设置LLM服务
                let provider = LLMProvider(rawValue: appState.userConfig.llmProvider) ?? .doubao
                podcastService.setupLLM(
                    apiKey: appState.userConfig.llmApiKey,
                    provider: provider,
                    model: appState.userConfig.llmModel
                )

                // 监听进度变化
                let progressTask = Task {
                    while !Task.isCancelled {
                        await MainActor.run {
                            let progress = podcastService.generationProgress

                            if progress < 0.3 {
                                currentStep = .fetchingRSS
                                stepProgress = progress / 0.3 * 0.25
                            } else if progress < 0.6 {
                                currentStep = .generatingScript
                                stepProgress = 0.25 + (progress - 0.3) / 0.3 * 0.5
                            } else if progress < 0.9 {
                                currentStep = .generatingAudio
                                stepProgress = 0.75 + (progress - 0.6) / 0.3 * 0.2
                            } else {
                                currentStep = .saving
                                stepProgress = 0.95 + (progress - 0.9) / 0.1 * 0.05
                            }
                        }
                        try? await Task.sleep(nanoseconds: 100_000_000)
                    }
                }

                // 生成播客
                let podcast = try await podcastService.generatePodcast(
                    topics: targetTopics,
                    config: appState.userConfig,
                    modelContext: modelContext
                )

                progressTask.cancel()

                await MainActor.run {
                    currentStep = .completed
                    stepProgress = 1.0

                    // 自动播放生成的播客
                    if let audioPath = podcast.audioFilePath {
                        let audioURL = URL(fileURLWithPath: audioPath)
                        audioPlayer.loadAndPlay(podcast: podcast, audioURL: audioURL)
                    }
                }

                try? await Task.sleep(nanoseconds: 500_000_000)

                await MainActor.run {
                    isGenerating = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    currentStep = .idle
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// 生成配置视图
struct GenerateConfigView: View {
    let topics: [Topic]
    let config: UserConfig
    let errorMessage: String?
    let onGenerate: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // 话题列表
            VStack(alignment: .leading, spacing: 8) {
                Text("将基于以下话题生成播客:")
                    .font(.headline)

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(topics) { topic in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(topic.name)
                            }
                        }
                    }
                }
                .frame(maxHeight: 150)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            // 配置信息
            VStack(alignment: .leading, spacing: 8) {
                Text("播客配置:")
                    .font(.headline)

                HStack {
                    Label("时长", systemImage: "clock")
                    Text("\(config.defaultLength) 分钟")
                    Spacer()
                }

                HStack {
                    Label("深度", systemImage: "chart.bar")
                    Text(config.contentDepth.rawValue)
                    Spacer()
                }

                HStack {
                    Label("风格", systemImage: "theatermasks")
                    Text(config.hostStyle.rawValue)
                    Spacer()
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Spacer()

            // 生成按钮
            Button(action: onGenerate) {
                Text("开始生成")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.accentColor)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
}

// 生成进度视图
struct GeneratingProgressView: View {
    let currentStep: GenerationStep
    let stepProgress: Double
    let currentStatus: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // 进度环
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: stepProgress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear, value: stepProgress)

                Text("\(Int(stepProgress * 100))%")
                    .font(.title2)
                    .fontWeight(.bold)
            }

            // 当前步骤
            VStack(spacing: 8) {
                Text(currentStep.title)
                    .font(.headline)

                if !currentStatus.isEmpty {
                    Text(currentStatus)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .multilineTextAlignment(.center)
                } else {
                    Text(currentStep.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            // 步骤列表
            VStack(alignment: .leading, spacing: 12) {
                ForEach(GenerationStep.allSteps, id: \.self) { step in
                    HStack(spacing: 12) {
                        Image(systemName: stepIcon(for: step))
                            .foregroundColor(stepColor(for: step))
                            .frame(width: 20)

                        Text(step.title)
                            .font(.caption)
                            .foregroundColor(stepColor(for: step))

                        Spacer()

                        if step == currentStep {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else if step.rawValue < currentStep.rawValue {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            Spacer()
        }
        .padding()
    }

    private func stepIcon(for step: GenerationStep) -> String {
        if step.rawValue < currentStep.rawValue {
            return "checkmark.circle.fill"
        } else if step == currentStep {
            return "circle.fill"
        } else {
            return "circle"
        }
    }

    private func stepColor(for step: GenerationStep) -> Color {
        if step.rawValue < currentStep.rawValue {
            return .green
        } else if step == currentStep {
            return .accentColor
        } else {
            return .secondary
        }
    }
}
