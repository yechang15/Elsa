import SwiftUI
import SwiftData

struct TopicsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Topic.priority, order: .reverse) private var topics: [Topic]

    @State private var showingAddSheet = false
    @State private var selectedTopics: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack {
                Text("兴趣话题管理")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button(action: { showingAddSheet = true }) {
                    Label("添加话题", systemImage: "plus.circle.fill")
                }
            }
            .padding()

            Divider()

            // 内容区
            if topics.isEmpty {
                EmptyTopicsView()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(topics) { topic in
                            TopicRow(topic: topic, onDelete: {
                                deleteTopic(topic)
                            })
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddTopicsSheet(existingTopics: topics.map { $0.name })
        }
    }

    private func deleteTopic(_ topic: Topic) {
        modelContext.delete(topic)
        try? modelContext.save()
    }
}

struct TopicRow: View {
    let topic: Topic
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(topic.name)
                    .font(.headline)

                HStack {
                    Text("优先级: \(topic.priority)")
                    Text("·")
                    if let lastGenerated = topic.lastGeneratedAt {
                        Text("最后生成: \(lastGenerated, style: .relative)")
                    } else {
                        Text("未生成过")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct EmptyTopicsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "tag")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("还没有话题")
                .font(.title2)
                .fontWeight(.semibold)

            Text("点击右上角按钮添加感兴趣的话题")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AddTopicsSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let existingTopics: [String]
    @State private var selectedTopics: Set<String> = []

    var availableTopics: [String] {
        Topic.presetTopics.filter { !existingTopics.contains($0) }
    }

    var body: some View {
        VStack(spacing: 20) {
            // 标题
            HStack {
                Text("添加话题")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button("取消") {
                    dismiss()
                }
            }
            .padding()

            Divider()

            if availableTopics.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.green)

                    Text("已添加所有预设话题")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(availableTopics, id: \.self) { topic in
                            TopicCard(
                                topic: topic,
                                isSelected: selectedTopics.contains(topic)
                            ) {
                                toggleTopic(topic)
                            }
                        }
                    }
                    .padding()
                }

                // 底部按钮
                VStack(spacing: 12) {
                    Text("已选择 \(selectedTopics.count) 个话题")
                        .font(.callout)
                        .foregroundColor(.secondary)

                    Button(action: addTopics) {
                        Text("添加")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(selectedTopics.isEmpty ? Color.gray : Color.accentColor)
                            .cornerRadius(8)
                    }
                    .disabled(selectedTopics.isEmpty)
                }
                .padding()
            }
        }
        .frame(width: 600, height: 500)
    }

    private func toggleTopic(_ topic: String) {
        if selectedTopics.contains(topic) {
            selectedTopics.remove(topic)
        } else {
            selectedTopics.insert(topic)
        }
    }

    private func addTopics() {
        let currentMaxPriority = existingTopics.count

        for (index, topicName) in selectedTopics.enumerated() {
            let topic = Topic(name: topicName, priority: currentMaxPriority + selectedTopics.count - index)

            // 为话题添加预设RSS源
            if let feedURLs = RSSFeed.presetFeeds[topicName] {
                for url in feedURLs {
                    let feed = RSSFeed(url: url, title: extractDomain(from: url), topic: topic)
                    topic.rssFeeds.append(feed)
                }
            }

            modelContext.insert(topic)
        }

        try? modelContext.save()
        dismiss()
    }

    private func extractDomain(from urlString: String) -> String {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return urlString
        }
        return host
    }
}

#Preview {
    TopicsView()
        .modelContainer(for: [Topic.self])
}
