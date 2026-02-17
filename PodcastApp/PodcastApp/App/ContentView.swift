import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var audioPlayer: AudioPlayer

    var body: some View {
        Group {
            if appState.isFirstLaunch {
                // 首次启动显示话题选择界面
                OnboardingView()
            } else {
                // 主界面
                MainView()
            }
        }
    }
}

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var podcastService: PodcastService

    @State private var showingGenerateSheet = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 主内容区
                HStack(spacing: 0) {
                    // 侧边栏
                    Sidebar()
                        .frame(width: 200)

                    Divider()

                    // 主内容
                    mainContent
                }

                Divider()

                // 底部播放控制栏
                if audioPlayer.currentPodcast != nil {
                    PlayerControlBar()
                        .frame(height: 80)
                }
            }

            // 浮动生成按钮
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { showingGenerateSheet = true }) {
                        Label("生成播客", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.accentColor)
                            .cornerRadius(25)
                            .shadow(radius: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(20)
                }
            }
        }
        .sheet(isPresented: $showingGenerateSheet) {
            GeneratePodcastSheet()
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch appState.selectedNavigation {
        case .podcastList:
            PodcastListView()
        case .topics:
            TopicsView()
        case .rss:
            RSSView()
        case .history:
            HistoryView()
        case .settings:
            SettingsView()
        }
    }
}

struct GeneratePodcastSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var podcastService: PodcastService

    @Query(sort: \Topic.priority, order: .reverse) private var topics: [Topic]

    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var currentStep: GenerationStep = .idle
    @State private var stepProgress: Double = 0.0

    var body: some View {
        VStack(spacing: 20) {
            // 标题
            HStack {
                Text("生成播客")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button("取消") {
                    dismiss()
                }
            }
            .padding()

            Divider()

            if topics.isEmpty {
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

                        Text(currentStep.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
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
            } else {
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
                            Text("\(appState.userConfig.defaultLength) 分钟")
                            Spacer()
                        }

                        HStack {
                            Label("深度", systemImage: "chart.bar")
                            Text(appState.userConfig.contentDepth.rawValue)
                            Spacer()
                        }

                        HStack {
                            Label("风格", systemImage: "theatermasks")
                            Text(appState.userConfig.hostStyle.rawValue)
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
                    Button(action: generatePodcast) {
                        if isGenerating {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("生成中...")
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                        } else {
                            Text("开始生成")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.accentColor)
                                .cornerRadius(8)
                        }
                    }
                    .disabled(isGenerating)
                    .buttonStyle(.plain)
                }
                .padding()
            }
        }
        .frame(width: 500, height: 600)
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

                            // 根据进度更新步骤
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
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                    }
                }

                // 生成播客
                let podcast = try await podcastService.generatePodcast(
                    topics: topics,
                    config: appState.userConfig,
                    modelContext: modelContext
                )

                progressTask.cancel()

                await MainActor.run {
                    currentStep = .completed
                    stepProgress = 1.0
                    print("播客生成成功: \(podcast.title)")
                    print("音频文件路径: \(podcast.audioFilePath ?? "无")")
                }

                // 延迟一下让用户看到完成状态
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒

                await MainActor.run {
                    isGenerating = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    currentStep = .idle
                    errorMessage = error.localizedDescription
                    print("生成失败: \(error.localizedDescription)")
                }
            }
        }
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

enum GenerationStep: Int {
    case idle = 0
    case fetchingRSS = 1
    case generatingScript = 2
    case generatingAudio = 3
    case saving = 4
    case completed = 5

    var title: String {
        switch self {
        case .idle: return "准备中"
        case .fetchingRSS: return "获取 RSS 内容"
        case .generatingScript: return "生成播客脚本"
        case .generatingAudio: return "合成音频"
        case .saving: return "保存播客"
        case .completed: return "完成"
        }
    }

    var description: String {
        switch self {
        case .idle: return "正在准备生成播客..."
        case .fetchingRSS: return "正在从 RSS 源获取最新文章..."
        case .generatingScript: return "AI 正在根据文章内容生成对话脚本..."
        case .generatingAudio: return "正在将脚本转换为音频文件..."
        case .saving: return "正在保存播客到数据库..."
        case .completed: return "播客生成完成！"
        }
    }

    static var allSteps: [GenerationStep] {
        [.fetchingRSS, .generatingScript, .generatingAudio, .saving]
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(RSSService())
        .environmentObject(PodcastService())
        .environmentObject(AudioPlayer())
}
