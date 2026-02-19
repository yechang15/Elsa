import SwiftUI

// 正在生成的播客卡片
struct GeneratingPodcastCard: View {
    @ObservedObject var generatingPodcast: GeneratingPodcast

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶部：话题名称
            HStack {
                Text(generatingPodcast.topicName)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                // 生成中指示器
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("生成中")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // 进度环
            HStack {
                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: generatingPodcast.stepProgress)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear, value: generatingPodcast.stepProgress)

                    Text("\(Int(generatingPodcast.stepProgress * 100))%")
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Spacer()
            }
            .padding(.vertical, 8)

            // 当前步骤
            VStack(alignment: .leading, spacing: 4) {
                Text(generatingPodcast.currentStep.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

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

            // 错误信息
            if let error = generatingPodcast.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(3)
            }

            Spacer()
        }
        .padding()
        .frame(height: 240)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 2)
        )
    }
}
