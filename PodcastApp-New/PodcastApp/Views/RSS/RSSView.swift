import SwiftUI
import SwiftData

struct RSSView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Topic.priority, order: .reverse) private var topics: [Topic]
    @EnvironmentObject var rssService: RSSService

    @State private var selectedTopic: Topic?
    @State private var showingAddFeedSheet = false
    @State private var testingFeeds: Set<UUID> = []
    @State private var feedTestResults: [UUID: FeedTestResult] = [:]

    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack {
                Text("RSS订阅管理")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button(action: refreshAllFeeds) {
                    Label("刷新全部", systemImage: "arrow.clockwise")
                }
            }
            .padding()

            Divider()

            // 内容区
            if topics.isEmpty {
                EmptyRSSView()
            } else {
                HSplitView {
                    // 左侧：话题列表
                    List(selection: $selectedTopic) {
                        ForEach(topics) { topic in
                            HStack {
                                Text(topic.name)
                                Spacer()
                                Text("\(topic.rssFeeds.count)")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .tag(topic)
                        }
                    }
                    .frame(minWidth: 200, maxWidth: 250)

                    // 右侧：RSS 源列表
                    if let topic = selectedTopic {
                        RSSFeedListView(
                            topic: topic,
                            testingFeeds: $testingFeeds,
                            feedTestResults: $feedTestResults,
                            onAddFeed: { showingAddFeedSheet = true },
                            onTestFeed: testFeed,
                            onDeleteFeed: deleteFeed
                        )
                    } else {
                        VStack {
                            Text("请选择一个话题")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddFeedSheet) {
            if let topic = selectedTopic {
                AddRSSFeedSheet(topic: topic)
            }
        }
        .onAppear {
            if selectedTopic == nil && !topics.isEmpty {
                selectedTopic = topics.first
            }
        }
    }

    private func refreshAllFeeds() {
        // 获取所有RSS源
        let allFeeds = topics.flatMap { $0.rssFeeds }

        guard !allFeeds.isEmpty else { return }

        // 清空之前的测试结果
        feedTestResults.removeAll()

        // 标记所有源为测试中
        for feed in allFeeds {
            testingFeeds.insert(feed.id)
        }

        // 创建feedId到feed对象的映射
        let feedMap = Dictionary(uniqueKeysWithValues: allFeeds.map { ($0.id, $0) })

        // 并发测试所有RSS源
        Task {
            await withTaskGroup(of: (UUID, FeedTestResult, Int).self) { group in
                for feed in allFeeds {
                    group.addTask {
                        do {
                            let articles = try await self.rssService.fetchFeed(url: feed.url)
                            return (feed.id, .success(articles.count), articles.count)
                        } catch {
                            return (feed.id, .failure(error.localizedDescription), 0)
                        }
                    }
                }

                // 收集所有结果
                for await (feedId, result, articleCount) in group {
                    await MainActor.run {
                        self.testingFeeds.remove(feedId)
                        self.feedTestResults[feedId] = result

                        // 如果测试成功，更新RSS源的元数据
                        if case .success = result, let feed = feedMap[feedId] {
                            feed.lastUpdated = Date()
                            feed.articleCount = articleCount
                        }
                    }
                }

                // 保存所有更新
                await MainActor.run {
                    try? self.modelContext.save()
                }
            }
        }
    }

    private func testFeed(_ feed: RSSFeed) {
        testingFeeds.insert(feed.id)

        Task {
            do {
                let articles = try await rssService.fetchFeed(url: feed.url)
                await MainActor.run {
                    testingFeeds.remove(feed.id)
                    feedTestResults[feed.id] = .success(articles.count)

                    // 更新RSS源的元数据
                    feed.lastUpdated = Date()
                    feed.articleCount = articles.count
                    try? modelContext.save()
                }
            } catch {
                await MainActor.run {
                    testingFeeds.remove(feed.id)
                    feedTestResults[feed.id] = .failure(error.localizedDescription)
                }
            }
        }
    }

    private func deleteFeed(_ feed: RSSFeed) {
        modelContext.delete(feed)
        try? modelContext.save()
    }
}

struct RSSFeedListView: View {
    let topic: Topic
    @Binding var testingFeeds: Set<UUID>
    @Binding var feedTestResults: [UUID: FeedTestResult]
    let onAddFeed: () -> Void
    let onTestFeed: (RSSFeed) -> Void
    let onDeleteFeed: (RSSFeed) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack {
                Text("\(topic.name) 的 RSS 源")
                    .font(.headline)

                Spacer()

                Button(action: onAddFeed) {
                    Label("添加源", systemImage: "plus.circle")
                }
            }
            .padding()

            Divider()

            if topic.rssFeeds.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)

                    Text("还没有 RSS 源")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("点击右上角按钮添加 RSS 源")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(topic.rssFeeds) { feed in
                            RSSFeedCard(
                                feed: feed,
                                isTesting: testingFeeds.contains(feed.id),
                                testResult: feedTestResults[feed.id],
                                onTest: { onTestFeed(feed) },
                                onDelete: { onDeleteFeed(feed) }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

struct RSSFeedCard: View {
    let feed: RSSFeed
    let isTesting: Bool
    let testResult: FeedTestResult?
    let onTest: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(feed.title)
                        .font(.headline)

                    Text(feed.url)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 8) {
                    if isTesting {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Button(action: onTest) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            // 状态信息（合并测试结果和RSS源状态）
            HStack {
                // 根据测试结果显示状态
                if let result = testResult {
                    switch result {
                    case .success:
                        Label("活跃", systemImage: "circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)

                        Text("·")
                            .foregroundColor(.secondary)

                        Text(feed.updateStatusText)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("·")
                            .foregroundColor(.secondary)

                        Text("\(feed.articleCount) 篇文章")
                            .font(.caption)
                            .foregroundColor(.secondary)

                    case .failure(let error):
                        Label("失败", systemImage: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.red)

                        Text("·")
                            .foregroundColor(.secondary)

                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .lineLimit(1)
                    }
                } else {
                    // 没有测试结果时，根据lastUpdated判断
                    if feed.lastUpdated != nil {
                        Label("活跃", systemImage: "circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Label("未测试", systemImage: "circle.fill")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Text("·")
                        .foregroundColor(.secondary)

                    Text(feed.updateStatusText)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("·")
                        .foregroundColor(.secondary)

                    Text("\(feed.articleCount) 篇文章")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct EmptyRSSView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("还没有话题")
                .font(.title2)
                .fontWeight(.semibold)

            Text("请先在「兴趣话题」页面添加话题")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AddRSSFeedSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var rssService: RSSService

    let topic: Topic

    @State private var feedURL = ""
    @State private var feedTitle = ""
    @State private var isTesting = false
    @State private var testResult: FeedTestResult?

    var body: some View {
        VStack(spacing: 20) {
            // 标题
            HStack {
                Text("添加 RSS 源")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button("取消") {
                    dismiss()
                }
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                Text("话题: \(topic.name)")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Text("RSS 地址")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TextField("https://example.com/feed.xml", text: $feedURL)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("名称（可选）")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TextField("自动从 RSS 源获取", text: $feedTitle)
                        .textFieldStyle(.roundedBorder)
                }

                Button(action: testFeed) {
                    if isTesting {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("测试中...")
                        }
                    } else {
                        Text("测试 RSS 源")
                    }
                }
                .disabled(feedURL.isEmpty || isTesting)

                if let result = testResult {
                    HStack {
                        switch result {
                        case .success(let count):
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("可用 - 获取到 \(count) 篇文章")
                                .foregroundColor(.green)
                        case .failure(let error):
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text("失败: \(error)")
                                .foregroundColor(.red)
                        }
                    }
                    .font(.caption)
                }
            }
            .padding()

            Spacer()

            Button(action: addFeed) {
                Text("添加")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(canAdd ? Color.accentColor : Color.gray)
                    .cornerRadius(8)
            }
            .disabled(!canAdd)
            .buttonStyle(.plain)
            .padding()
        }
        .frame(width: 500, height: 400)
    }

    private var canAdd: Bool {
        !feedURL.isEmpty && testResult != nil && !isTesting
    }

    private func testFeed() {
        isTesting = true
        testResult = nil

        Task {
            do {
                let articles = try await rssService.fetchFeed(url: feedURL)
                await MainActor.run {
                    isTesting = false
                    testResult = .success(articles.count)
                }
            } catch {
                await MainActor.run {
                    isTesting = false
                    testResult = .failure(error.localizedDescription)
                }
            }
        }
    }

    private func addFeed() {
        let title = feedTitle.isEmpty ? extractDomain(from: feedURL) : feedTitle
        let feed = RSSFeed(url: feedURL, title: title, topic: topic)
        topic.rssFeeds.append(feed)

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

enum FeedTestResult {
    case success(Int)
    case failure(String)
}

#Preview {
    RSSView()
        .environmentObject(RSSService())
        .modelContainer(for: [Topic.self, RSSFeed.self])
}

