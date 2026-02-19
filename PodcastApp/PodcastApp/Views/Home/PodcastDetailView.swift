import SwiftUI

struct PodcastDetailView: View {
    let podcast: Podcast
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var appState: AppState

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

            // 封面图
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [coverColor.opacity(0.6), coverColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 200, height: 200)
                .overlay(
                    Image(systemName: "waveform")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.3))
                )

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

            // 播放控制
            HStack(spacing: 20) {
                Button(action: playPodcast) {
                    Label(isCurrentlyPlaying ? "暂停" : "播放", systemImage: isCurrentlyPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.borderedProminent)

                Button(action: {}) {
                    Label("收藏", systemImage: "heart")
                        .font(.body)
                }
                .buttonStyle(.bordered)

                Button(action: {}) {
                    Label("分享", systemImage: "square.and.arrow.up")
                        .font(.body)
                }
                .buttonStyle(.bordered)
            }

            // 播放进度
            VStack(spacing: 4) {
                ProgressView(value: podcast.playProgress)
                    .tint(.accentColor)

                HStack {
                    Text("播放进度 \(Int(podcast.playProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(podcast.playStatus.displayText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    private var coverColor: Color {
        let colors: [Color] = [
            .blue, .purple, .pink, .orange, .green, .teal, .indigo, .cyan
        ]
        let hash = podcast.topics.first?.hashValue ?? podcast.title.hashValue
        return colors[abs(hash) % colors.count]
    }

    private var isCurrentlyPlaying: Bool {
        audioPlayer.currentPodcast?.id == podcast.id && audioPlayer.isPlaying
    }

    private func playPodcast() {
        if isCurrentlyPlaying {
            audioPlayer.pause()
        } else {
            guard let audioPath = podcast.audioFilePath else { return }
            let audioURL = URL(fileURLWithPath: audioPath)
            audioPlayer.loadAndPlay(podcast: podcast, audioURL: audioURL)
        }
    }
}
