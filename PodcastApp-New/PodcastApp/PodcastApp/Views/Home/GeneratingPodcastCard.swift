import SwiftUI

struct GeneratingPodcastCard: View {
    @ObservedObject var generatingPodcast: GeneratingPodcast
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部：进度圆环 + 取消按钮
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(cardColor.opacity(0.15))
                        .frame(width: 36, height: 36)

                    if generatingPodcast.errorMessage != nil {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.red)
                    } else {
                        ZStack {
                            Circle()
                                .stroke(cardColor.opacity(0.3), lineWidth: 3)
                                .frame(width: 22, height: 22)
                            Circle()
                                .trim(from: 0, to: generatingPodcast.stepProgress)
                                .stroke(cardColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .frame(width: 22, height: 22)
                                .rotationEffect(.degrees(-90))
                                .animation(.linear, value: generatingPodcast.stepProgress)
                        }
                    }
                }

                Spacer()

                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 10)

            // 话题名称
            Text(generatingPodcast.topicName)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(3)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            // 状态文字
            Group {
                if let error = generatingPodcast.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.red)
                        .lineLimit(2)
                } else {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 12, height: 12)
                        Text(generatingPodcast.currentStatus.isEmpty
                             ? generatingPodcast.currentStep.title
                             : generatingPodcast.currentStatus)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.bottom, 6)

            // 进度条占位（保持与 PodcastGridCard 高度一致）
            ProgressView(value: generatingPodcast.stepProgress)
                .tint(cardColor)
                .scaleEffect(y: 0.6)
        }
        .padding(12)
        .frame(minHeight: 150)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private var cardColor: Color {
        generatingPodcast.errorMessage != nil ? .red : .accentColor
    }
}
