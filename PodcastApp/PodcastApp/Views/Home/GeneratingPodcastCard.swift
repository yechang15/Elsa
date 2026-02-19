import SwiftUI

// 正在生成的播客卡片
struct GeneratingPodcastCard: View {
    @ObservedObject var generatingPodcast: GeneratingPodcast
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 顶部：话题名称和时间
            HStack {
                Text(generatingPodcast.topicName)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Text(generatingPodcast.createdAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 配置信息
            HStack(spacing: 12) {
                Label("\(generatingPodcast.config.defaultLength)分钟", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Label(generatingPodcast.config.contentDepth.rawValue, systemImage: "chart.bar")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Label(generatingPodcast.config.hostStyle.rawValue, systemImage: "theatermasks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // 进度和状态
            HStack(spacing: 16) {
                // 进度环
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 5)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: generatingPodcast.stepProgress)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear, value: generatingPodcast.stepProgress)

                    Text("\(Int(generatingPodcast.stepProgress * 100))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                // 当前步骤
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text(generatingPodcast.currentStep.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    if !generatingPodcast.currentStatus.isEmpty {
                        Text(generatingPodcast.currentStatus)
                            .font(.caption)
                            .foregroundColor(.blue)
                            .lineLimit(2)
                    } else {
                        Text(generatingPodcast.currentStep.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()
            }

            // 错误信息
            if let error = generatingPodcast.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(2)
            }

            // 取消按钮
            Button(action: onCancel) {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text("取消生成")
                }
                .font(.caption)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.1))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 2)
        )
    }
}
