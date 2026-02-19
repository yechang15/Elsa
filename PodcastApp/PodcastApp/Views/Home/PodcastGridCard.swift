import SwiftUI

// 播客网格卡片（用于首页瀑布流布局）
struct PodcastGridCard: View {
    let podcast: Podcast
    @EnvironmentObject var audioPlayer: AudioPlayer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 封面图区域
            ZStack(alignment: .bottomTrailing) {
                // 封面图（暂时使用渐变色作为占位）
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [coverColor.opacity(0.6), coverColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .aspectRatio(1.0, contentMode: .fit)
                    .overlay(
                        Image(systemName: "waveform")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.3))
                    )

                // 播放/暂停按钮
                Button(action: togglePlayPause) {
                    Image(systemName: isCurrentlyPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                        .shadow(radius: 4)
                }
                .buttonStyle(.plain)
                .padding(8)
            }

            // 标题
            Text(podcast.title)
                .font(.headline)
                .lineLimit(2)
                .foregroundColor(.primary)

            // 话题标签
            if !podcast.topics.isEmpty {
                Text(podcast.topics.joined(separator: " · "))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            // 时长和日期
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption2)
                Text(podcast.formattedDuration)
                    .font(.caption)

                Spacer()

                Text(podcast.createdAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .foregroundColor(.secondary)

            // 播放进度（始终显示，保持卡片高度一致）
            VStack(spacing: 4) {
                ProgressView(value: podcast.playProgress)
                    .tint(progressColor)
                    .scaleEffect(y: 0.5)
            }
            .frame(height: 8) // 固定高度
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // 根据话题生成封面颜色
    private var coverColor: Color {
        let colors: [Color] = [
            .blue, .purple, .pink, .orange, .green, .teal, .indigo, .cyan
        ]
        let hash = podcast.topics.first?.hashValue ?? podcast.title.hashValue
        return colors[abs(hash) % colors.count]
    }

    private var progressColor: Color {
        switch podcast.playStatus {
        case .notStarted: return .gray
        case .inProgress: return .blue
        case .completed: return .green
        }
    }

    // 判断当前播客是否正在播放
    private var isCurrentlyPlaying: Bool {
        audioPlayer.currentPodcast?.id == podcast.id && audioPlayer.isPlaying
    }

    // 切换播放/暂停
    private func togglePlayPause() {
        if isCurrentlyPlaying {
            // 如果当前播客正在播放，则暂停
            audioPlayer.pause()
        } else {
            // 否则播放该播客
            guard let audioPath = podcast.audioFilePath else { return }
            let audioURL = URL(fileURLWithPath: audioPath)
            audioPlayer.loadAndPlay(podcast: podcast, audioURL: audioURL)
        }
    }
}
