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
    @State private var showingGenerateSheet = false

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
                    Button(action: { showingGenerateSheet = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("为「\(selectedTopic)」生成播客")
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
                if filteredPodcasts.isEmpty {
                    EmptyStateView()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
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
        .sheet(isPresented: $showingGenerateSheet) {
            GeneratePodcastSheetForTopic(selectedTopic: selectedTopic)
        }
    }

    // 所有话题列表（推荐、全部、各个话题）
    private var allTopics: [String] {
        var topicList = ["推荐", "全部"]
        topicList.append(contentsOf: topics.map { $0.name })
        return topicList
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
