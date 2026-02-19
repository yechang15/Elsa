import SwiftUI

// 播客网格卡片（用于首页瀑布流布局）
struct PodcastGridCard: View {
    let podcast: Podcast

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

                // 播放图标（装饰性，不可点击）
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
                    .shadow(radius: 4)
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

                Text(podcast.createdAt, format: .dateTime.month().day())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .foregroundColor(.secondary)

            // 播放进度
            if podcast.playProgress > 0 {
                ProgressView(value: podcast.playProgress)
                    .tint(progressColor)
                    .scaleEffect(y: 0.5)
            }
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
}
