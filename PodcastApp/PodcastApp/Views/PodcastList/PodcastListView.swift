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
                            PodcastCard(podcast: podcast)
                                .onTapGesture {
                                    playPodcast(podcast)
                                }
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题和话题
            VStack(alignment: .leading, spacing: 4) {
                Text(podcast.title)
                    .font(.headline)
                
                Text(podcast.topics.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 时长和日期
            HStack {
                Text(podcast.formattedDuration)
                Text("·")
                Text(podcast.createdAt, style: .date)
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            // 播放进度
            ProgressView(value: podcast.playProgress)
                .tint(progressColor(for: podcast.playStatus))
            
            Text("\(Int(podcast.playProgress * 100))% \(podcast.playStatus.displayText)")
                .font(.caption)
                .foregroundColor(.secondary)
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
