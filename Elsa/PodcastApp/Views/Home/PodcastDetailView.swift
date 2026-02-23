import SwiftUI

struct PodcastDetailView: View {
    let podcast: Podcast
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var behaviorTracker: BehaviorTracker

    @State private var selectedTab: DetailTab = .script

    enum DetailTab: String, CaseIterable {
        case script = "文稿"
        case sources = "来源"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 头部区域
            headerSection

            Divider()

            // 标签页选择器
            Picker("", selection: $selectedTab) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // 标签页内容
            Group {
                if selectedTab == .script {
                    ScriptView(podcast: podcast)
                } else {
                    SourceArticlesView(articles: podcast.sourceArticles)
                }
            }
        }
        .onAppear {
            // 记录播客查看行为
            behaviorTracker.recordPodcastView(podcast: podcast, sourceScreen: "detail")
            // 切换到新播客时自动播放
            if audioPlayer.currentPodcast?.id != podcast.id {
                guard let audioPath = podcast.audioFilePath else { return }
                let audioURL = URL(fileURLWithPath: audioPath)
                audioPlayer.loadAndPlay(podcast: podcast, audioURL: audioURL)
            }
        }
    }

    // 头部区域
    private var headerSection: some View {
        VStack(spacing: 16) {
            // 顶部工具栏
            HStack {
                Button(action: { appState.selectedPodcast = nil }) {
                    Label("返回", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)

                Spacer()

                Menu {
                    Button("分享") {
                        // TODO: 实现分享功能
                    }
                    Button("删除", role: .destructive) {
                        // TODO: 实现删除功能
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding()

            // 标题和信息
            VStack(spacing: 8) {
                Text(podcast.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                HStack(spacing: 8) {
                    if !podcast.topics.isEmpty {
                        Text(podcast.topics.joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Text("·")
                        .foregroundColor(.secondary)
                    Text(podcast.formattedDuration)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("·")
                        .foregroundColor(.secondary)
                    Text(podcast.createdAt, format: .dateTime.month().day())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
}
