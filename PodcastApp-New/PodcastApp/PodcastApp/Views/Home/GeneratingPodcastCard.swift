import SwiftUI

// 正在生成的播客卡片
struct GeneratingPodcastCard: View {
    @ObservedObject var generatingPodcast: GeneratingPodcast
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 封面占位区域（与 PodcastGridCard 保持一致的高度）
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        colors: placeholderColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .aspectRatio(1.0, contentMode: .fit)

                if generatingPodcast.errorMessage != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.8))
                } else {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 5)
                            .frame(width: 60, height: 60)

                        Circle()
                            .trim(from: 0, to: generatingPodcast.stepProgress)
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear, value: generatingPodcast.stepProgress)

                        Text("\(Int(generatingPodcast.stepProgress * 100))%")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                }
            }

            // 话题名称
            Text(generatingPodcast.topicName)
                .font(.headline)
                .lineLimit(2)
                .foregroundColor(.primary)

            // 配置信息
            HStack(spacing: 8) {
                Label(generatingPodcast.config.contentDepth.rawValue, systemImage: "chart.bar")
                Label(generatingPodcast.config.hostStyle.rawValue, systemImage: "theatermasks")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(1)

            // 时长和日期
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption2)
                Text("\(generatingPodcast.config.defaultLength)分钟")
                    .font(.caption)

                Spacer()

                Text(generatingPodcast.createdAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .foregroundColor(.secondary)

            // 状态文字（固定高度，与 PodcastGridCard 进度条区域对齐）
            Group {
                if let error = generatingPodcast.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(2)
                } else {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text(generatingPodcast.currentStatus.isEmpty
                             ? generatingPodcast.currentStep.title
                             : generatingPodcast.currentStatus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(height: 16)

            // 取消/关闭按钮（白底红字）
            Button(action: onCancel) {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text(generatingPodcast.errorMessage != nil ? "关闭" : "取消生成")
                }
                .font(.caption)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.white)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private var placeholderColors: [Color] {
        if generatingPodcast.errorMessage != nil {
            return [Color.red.opacity(0.4), Color.red.opacity(0.7)]
        }
        return [Color.accentColor.opacity(0.4), Color.accentColor.opacity(0.7)]
    }
}
