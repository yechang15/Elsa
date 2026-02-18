import SwiftUI
import SwiftData

struct PodcastListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Podcast.createdAt, order: .reverse) private var podcasts: [Podcast]
    @EnvironmentObject var audioPlayer: AudioPlayer
    
    @State private var selectedFilter: FilterOption = .all
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack {
                Text("播客列表")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                // 筛选按钮
                Menu {
                    ForEach(FilterOption.allCases, id: \.self) { option in
                        Button(option.rawValue) {
                            selectedFilter = option
                        }
                    }
                } label: {
                    Label(selectedFilter.rawValue, systemImage: "line.3.horizontal.decrease.circle")
                }
            }
            .padding()
            
            Divider()
            
            // 播客列表
            if filteredPodcasts.isEmpty {
                EmptyStateView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredPodcasts) { podcast in
                            PodcastCard(podcast: podcast, onPlay: {
                                playPodcast(podcast)
                            })
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    private var filteredPodcasts: [Podcast] {
        switch selectedFilter {
        case .all:
            return podcasts
        case .notStarted:
            return podcasts.filter { $0.playStatus == .notStarted }
        case .inProgress:
            return podcasts.filter { $0.playStatus == .inProgress }
        case .completed:
            return podcasts.filter { $0.playStatus == .completed }
        }
    }
    
    private func playPodcast(_ podcast: Podcast) {
        guard let audioPath = podcast.audioFilePath else { return }
        let audioURL = URL(fileURLWithPath: audioPath)
        audioPlayer.loadAndPlay(podcast: podcast, audioURL: audioURL)
    }
}

struct PodcastCard: View {
    let podcast: Podcast
    let onPlay: () -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题和话题
            HStack(alignment: .top, spacing: 12) {
                // 播放按钮
                Button(action: onPlay) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("播放播客")

                VStack(alignment: .leading, spacing: 4) {
                    Text(podcast.title)
                        .font(.headline)

                    Text(podcast.topics.joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // 时长和日期
            HStack {
                Text(podcast.formattedDuration)
                Text("·")
                Text(podcast.createdAt, format: .dateTime.year().month().day().hour().minute())
                Text("·")
                Text("\(podcast.length) 分钟")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            // 播放进度
            ProgressView(value: podcast.playProgress)
                .tint(progressColor(for: podcast.playStatus))

            HStack {
                Text("\(Int(podcast.playProgress * 100))% \(podcast.playStatus.displayText)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: { isExpanded.toggle() }) {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "收起详情" : "查看详情")
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }

            // 详细信息（可展开）
            if isExpanded {
                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    // RSS 来源文章
                    if !podcast.sourceArticles.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("RSS 来源文章 (\(podcast.sourceArticles.count) 篇)")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            ScrollView {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(Array(podcast.sourceArticles.enumerated()), id: \.offset) { index, article in
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text("\(index + 1).")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)

                                                Text(article.title)
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                            }

                                            if !article.description.isEmpty {
                                                Text(article.description)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(2)
                                            }

                                            HStack {
                                                Text(article.formattedPubDate)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)

                                                Spacer()

                                                if let url = URL(string: article.link) {
                                                    Link("查看原文", destination: url)
                                                        .font(.caption)
                                                }
                                            }
                                        }
                                        .padding(8)
                                        .background(Color(NSColor.textBackgroundColor))
                                        .cornerRadius(6)
                                    }
                                }
                            }
                            .frame(maxHeight: 200)
                        }
                    }

                    // 配置信息
                    VStack(alignment: .leading, spacing: 4) {
                        Text("播客配置")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        HStack {
                            Label("风格", systemImage: "theatermasks")
                            Text(podcast.hostStyle)
                            Spacer()
                            Label("深度", systemImage: "chart.bar")
                            Text(podcast.contentDepth)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }

                    // 音频文件信息
                    if let audioPath = podcast.audioFilePath {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("音频文件")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Text(audioPath)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)

                            // 检查文件是否存在
                            if FileManager.default.fileExists(atPath: audioPath) {
                                Label("文件存在", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                         Label("文件不存在", systemImage: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    // 播客文稿
                    VStack(alignment: .leading, spacing: 4) {
                        Text("播客文稿")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        ScrollView {
                            Text(podcast.scriptContent)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                        }
                        .frame(maxHeight: 300)
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private func progressColor(for status: PlayStatus) -> Color {
        switch status {
        case .notStarted: return .gray
        case .inProgress: return .blue
        case .completed: return .green
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "headphones")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("还没有播客")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("点击下方按钮生成你的第一个播客")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

enum FilterOption: String, CaseIterable {
    case all = "全部"
    case notStarted = "未听"
    case inProgress = "进行中"
    case completed = "已听完"
}

#Preview {
    PodcastListView()
        .environmentObject(AudioPlayer())
        .modelContainer(for: [Podcast.self])
}
