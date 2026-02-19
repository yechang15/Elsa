import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Podcast.createdAt, order: .reverse) private var podcasts: [Podcast]
    @Query(sort: \Topic.priority, order: .reverse) private var topics: [Topic]
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var podcastService: PodcastService

    @State private var selectedTopic: String = "推荐"
    @State private var generatingPodcasts: [GeneratingPodcast] = []

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // 话题标签栏
            TopicTabBar(
                topics: allTopics,
                selectedTopic: $selectedTopic
            )
            .padding(.horizontal)
            .padding(.vertical, 12)

            Divider()

            // 内容区域
            VStack(spacing: 0) {
                // 生成播客按钮
                HStack {
                    Button(action: startGeneratingPodcast) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text(generateButtonText)
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .cornerRadius(20)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 12)

                // 播客网格
                if filteredPodcasts.isEmpty && generatingPodcasts.isEmpty {
                    EmptyStateView()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            // 正在生成的播客卡片
                            ForEach(generatingPodcasts) { generatingPodcast in
                                GeneratingPodcastCard(
                                    generatingPodcast: generatingPodcast,
                                    onCancel: {
                                        cancelGeneration(generatingPodcast)
                                    }
                                )
                            }

                            // 已生成的播客卡片
                            ForEach(filteredPodcasts) { podcast in
                                PodcastGridCard(podcast: podcast)
                                    .onTapGesture {
                                        // 只进入详情页，不自动播放
                                        appState.selectedPodcast = podcast
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
        }
    }

    // 所有话题列表（推荐、全部、各个话题）
    private var allTopics: [String] {
        var topicList = ["推荐", "全部"]
        topicList.append(contentsOf: topics.map { $0.name })
        return topicList
    }

    // 生成按钮文本
    private var generateButtonText: String {
        if selectedTopic == "推荐" {
            // 推荐模式：显示将为哪个话题生成
            if let firstTopic = topics.first {
                return "为「\(firstTopic.name)」生成播客"
            } else {
                return "生成播客"
            }
        } else {
            return "为「\(selectedTopic)」生成播客"
        }
    }

    // 根据选中的话题筛选播客
    private var filteredPodcasts: [Podcast] {
        if selectedTopic == "推荐" {
            // 推荐：每个用户选择的话题下，只有单个话题的播客中的最新一条
            var recommendedPodcasts: [Podcast] = []

            for topic in topics {
                // 找到该话题的单话题播客（topics数组只有这一个话题）
                let topicPodcasts = podcasts.filter {
                    $0.topics.count == 1 && $0.topics.first == topic.name
                }

                // 取最新的一条
                if let latestPodcast = topicPodcasts.first {
                    recommendedPodcasts.append(latestPodcast)
                }
            }

            // 按创建时间排序（最新的在前）
            return recommendedPodcasts.sorted { $0.createdAt > $1.createdAt }
        } else if selectedTopic == "全部" {
            return podcasts
        } else {
            // 只显示topics数组中只有这一个话题的播客
            return podcasts.filter { podcast in
                podcast.topics.count == 1 && podcast.topics.first == selectedTopic
            }
        }
    }

    // 开始生成播客
    private func startGeneratingPodcast() {
        // 创建生成中的播客对象
        let generatingPodcast = GeneratingPodcast(
            topicName: selectedTopic,
            topics: targetTopics,
            config: appState.userConfig
        )

        // 添加到列表
        generatingPodcasts.insert(generatingPodcast, at: 0)

        // 在后台执行生成任务
        let task = Task {
            await generatePodcast(generatingPodcast)
        }

        // 保存任务引用以便取消
        generatingPodcast.generationTask = task
    }

    // 目标话题列表
    private var targetTopics: [Topic] {
        if selectedTopic == "推荐" {
            // 推荐模式：只为第一个话题生成，确保是单话题播客
            return topics.isEmpty ? [] : [topics[0]]
        } else if selectedTopic == "全部" {
            return topics
        } else {
            return topics.filter { $0.name == selectedTopic }
        }
    }

    // 生成播客
    private func generatePodcast(_ generatingPodcast: GeneratingPodcast) async {
        do {
            // 检查是否已取消
            guard !generatingPodcast.isCancelled else {
                await MainActor.run {
                    generatingPodcasts.removeAll { $0.id == generatingPodcast.id }
                }
                return
            }

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
                    // 检查是否已取消
                    if generatingPodcast.isCancelled {
                        break
                    }

                    await MainActor.run {
                        let progress = podcastService.generationProgress
                        let status = podcastService.currentStatus

                        generatingPodcast.currentStatus = status

                        if progress < 0.3 {
                            generatingPodcast.currentStep = .fetchingRSS
                            generatingPodcast.stepProgress = progress / 0.3 * 0.25
                        } else if progress < 0.6 {
                            generatingPodcast.currentStep = .generatingScript
                            generatingPodcast.stepProgress = 0.25 + (progress - 0.3) / 0.3 * 0.5
                        } else if progress < 0.9 {
                            generatingPodcast.currentStep = .generatingAudio
                            generatingPodcast.stepProgress = 0.75 + (progress - 0.6) / 0.3 * 0.2
                        } else {
                            generatingPodcast.currentStep = .saving
                            generatingPodcast.stepProgress = 0.95 + (progress - 0.9) / 0.1 * 0.05
                        }
                    }
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
            }

            // 生成播客
            let podcast = try await podcastService.generatePodcast(
                topics: generatingPodcast.topics,
                config: appState.userConfig,
                modelContext: modelContext
            )

            progressTask.cancel()

            // 再次检查是否已取消
            guard !generatingPodcast.isCancelled else {
                await MainActor.run {
                    generatingPodcasts.removeAll { $0.id == generatingPodcast.id }
                }
                return
            }

            await MainActor.run {
                generatingPodcast.currentStep = .completed
                generatingPodcast.stepProgress = 1.0
                generatingPodcast.generatedPodcast = podcast
                generatingPodcast.isCompleted = true

                // 自动播放生成的播客
                if let audioPath = podcast.audioFilePath {
                    let audioURL = URL(fileURLWithPath: audioPath)
                    audioPlayer.loadAndPlay(podcast: podcast, audioURL: audioURL)
                }
            }

            // 等待一下让用户看到完成状态，并确保SwiftData查询已更新
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            // 从生成列表中移除
            await MainActor.run {
                generatingPodcasts.removeAll { $0.id == generatingPodcast.id }
            }
        } catch {
            await MainActor.run {
                generatingPodcast.errorMessage = error.localizedDescription
                generatingPodcast.currentStep = .idle
            }
        }
    }

    // 取消生成
    private func cancelGeneration(_ generatingPodcast: GeneratingPodcast) {
        generatingPodcast.cancel()
        generatingPodcasts.removeAll { $0.id == generatingPodcast.id }
    }
}

// 话题标签栏组件
struct TopicTabBar: View {
    let topics: [String]
    @Binding var selectedTopic: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(topics, id: \.self) { topic in
                    TopicTab(
                        title: topic,
                        isSelected: selectedTopic == topic
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTopic = topic
                        }
                    }
                }
            }
        }
    }
}

// 话题标签
struct TopicTab: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(isSelected ? .semibold : .regular)
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
            )
    }
}
