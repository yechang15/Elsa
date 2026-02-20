import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState

    @State private var selectedTopics: Set<String> = []

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // 标题
            VStack(spacing: 16) {
                Text("欢迎使用对话式播客应用")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("选择你感兴趣的话题，我们将为你生成个性化播客")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            // 话题选择网格
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(Topic.presetTopics, id: \.self) { topic in
                    TopicCard(
                        topic: topic,
                        isSelected: selectedTopics.contains(topic)
                    ) {
                        toggleTopic(topic)
                    }
                }
            }
            .padding(.horizontal, 40)

            // 已选择提示
            Text("已选择 \(selectedTopics.count) 个话题（至少选择 1 个）")
                .font(.callout)
                .foregroundColor(.secondary)

            // 开始使用按钮
            Button(action: completeOnboarding) {
                Text("开始使用")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 200, height: 44)
                    .background(selectedTopics.isEmpty ? Color.gray : Color.accentColor)
                    .cornerRadius(8)
            }
            .disabled(selectedTopics.isEmpty)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func toggleTopic(_ topic: String) {
        if selectedTopics.contains(topic) {
            selectedTopics.remove(topic)
        } else {
            selectedTopics.insert(topic)
        }
    }

    private func completeOnboarding() {
        // 创建选中的话题
        for (index, topicName) in selectedTopics.enumerated() {
            let topic = Topic(name: topicName, priority: selectedTopics.count - index)

            // 为话题添加预设RSS源
            if let feedURLs = RSSFeed.presetFeeds[topicName] {
                for url in feedURLs {
                    let feed = RSSFeed(url: url, title: extractDomain(from: url), topic: topic)
                    topic.rssFeeds.append(feed)
                }
            }

            modelContext.insert(topic)
        }

        // 保存数据
        try? modelContext.save()

        // 完成引导
        appState.completeOnboarding()
    }

    private func extractDomain(from urlString: String) -> String {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return urlString
        }
        return host
    }
}

struct TopicCard: View {
    let topic: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                Text(topic)
                    .font(.body)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding()
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
        .modelContainer(for: [Topic.self, RSSFeed.self])
}
