import SwiftUI

struct PodcastGridCard: View {
    let podcast: Podcast
    @EnvironmentObject var audioPlayer: AudioPlayer

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部：话题图标 + 播放按钮
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(coverColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: topicIcon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(coverColor)
                }

                Spacer()

                Button(action: togglePlayPause) {
                    Image(systemName: isCurrentlyPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 10)

            // 标题（主体）
            Text(podcast.title)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(3)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            // 话题标签
            if !podcast.topics.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(podcast.topics, id: \.self) { topic in
                            Text(topic)
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding(.bottom, 4)
            }

            // 时间 + 时长
            HStack(spacing: 4) {
                Text(podcast.createdAt, format: .dateTime.year().month().day().hour().minute())
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: "clock")
                    .font(.caption2)
                Text(podcast.formattedDuration)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 6)

            // 播放进度
            ProgressView(value: podcast.playProgress)
                .tint(progressColor)
                .scaleEffect(y: 0.6)
        }
        .padding(12)
        .frame(minHeight: 150)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private var topicIcon: String {
        let iconMap: [String: String] = [
            "Swift 开发": "chevron.left.forwardslash.chevron.right",
            "前端开发": "globe",
            "后端架构": "server.rack",
            "移动开发": "iphone",
            "AI 技术": "brain",
            "数据科学": "chart.bar.xaxis",
            "DevOps": "terminal",
            "开源项目": "folder.badge.gearshape",
            "Web3 & 区块链": "link",
            "云计算": "cloud",
            "产品设计": "pencil.and.ruler",
            "UX 研究": "person.crop.rectangle",
            "UI 设计": "paintbrush",
            "交互设计": "hand.tap",
            "创业": "lightbulb",
            "科技新闻": "newspaper",
            "商业分析": "chart.line.uptrend.xyaxis",
            "投资理财": "dollarsign.circle",
            "营销增长": "megaphone",
            "健康养生": "heart",
            "心理学": "brain.head.profile",
            "个人成长": "figure.walk",
            "阅读写作": "book",
            "播客推荐": "headphones",
            "电影评论": "film",
            "音乐推荐": "music.note",
            "游戏资讯": "gamecontroller",
            "动漫二次元": "sparkles",
            "天文物理": "star",
            "生物医学": "cross.case",
            "环境科学": "leaf",
            "科普知识": "flask"
        ]
        return iconMap[podcast.topics.first ?? ""] ?? "waveform"
    }

    private var coverColor: Color {
        let colorMap: [String: Color] = [
            "Swift 开发":    .orange,
            "前端开发":      .cyan,
            "后端架构":      .indigo,
            "移动开发":      .blue,
            "AI 技术":       .purple,
            "数据科学":      .teal,
            "DevOps":        Color(red: 0.2, green: 0.6, blue: 0.3),
            "开源项目":      Color(red: 0.8, green: 0.5, blue: 0.1),
            "Web3 & 区块链": Color(red: 0.4, green: 0.2, blue: 0.9),
            "云计算":        Color(red: 0.1, green: 0.6, blue: 0.8),
            "产品设计":      .pink,
            "UX 研究":       Color(red: 0.9, green: 0.4, blue: 0.6),
            "UI 设计":       Color(red: 0.95, green: 0.3, blue: 0.5),
            "交互设计":      Color(red: 0.7, green: 0.2, blue: 0.7),
            "创业":          .yellow,
            "科技新闻":      Color(red: 0.3, green: 0.5, blue: 0.9),
            "商业分析":      Color(red: 0.1, green: 0.5, blue: 0.4),
            "投资理财":      Color(red: 0.2, green: 0.7, blue: 0.3),
            "营销增长":      Color(red: 0.9, green: 0.5, blue: 0.1),
            "健康养生":      .green,
            "心理学":        Color(red: 0.5, green: 0.3, blue: 0.8),
            "个人成长":      Color(red: 0.2, green: 0.7, blue: 0.6),
            "阅读写作":      Color(red: 0.6, green: 0.4, blue: 0.2),
            "播客推荐":      Color(red: 0.8, green: 0.3, blue: 0.7),
            "电影评论":      Color(red: 0.7, green: 0.1, blue: 0.2),
            "音乐推荐":      Color(red: 0.9, green: 0.2, blue: 0.5),
            "游戏资讯":      Color(red: 0.3, green: 0.7, blue: 0.2),
            "动漫二次元":    Color(red: 0.95, green: 0.4, blue: 0.7),
            "天文物理":      Color(red: 0.1, green: 0.2, blue: 0.7),
            "生物医学":      Color(red: 0.8, green: 0.2, blue: 0.3),
            "环境科学":      Color(red: 0.2, green: 0.6, blue: 0.2),
            "科普知识":      Color(red: 0.1, green: 0.5, blue: 0.6),
        ]
        return colorMap[podcast.topics.first ?? ""] ?? .blue
    }

    private var progressColor: Color {
        switch podcast.playStatus {
        case .notStarted: return .gray
        case .inProgress: return .blue
        case .completed: return .green
        }
    }

    private var isCurrentlyPlaying: Bool {
        audioPlayer.currentPodcast?.id == podcast.id && audioPlayer.isPlaying
    }

    private func togglePlayPause() {
        if isCurrentlyPlaying {
            audioPlayer.pause()
        } else {
            guard let audioPath = podcast.audioFilePath else { return }
            let audioURL = URL(fileURLWithPath: audioPath)
            audioPlayer.loadAndPlay(podcast: podcast, audioURL: audioURL)
        }
    }
}
