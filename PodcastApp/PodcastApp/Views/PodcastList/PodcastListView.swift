import SwiftUI
import SwiftData

struct PodcastListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Podcast.createdAt, order: .reverse) private var podcasts: [Podcast]
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var schedulerService: SchedulerService

    @State private var selectedFilter: FilterOption = .all
    @State private var expandedCategories: Set<String> = [] // 记录展开的分类

    private let defaultDisplayCount = 3 // 默认显示的播客数量

    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack {
                Text("播客列表")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                // 筛选按钮
                Menu {
                    ForEach(FilterOption.allCases, id: \.self) { option in
                        Button(option.rawValue) {
                            selectedFilter = option
                        }
                    }
                } label: {
                    Label(selectedFilter.rawValue, systemImage: "line.3.horizontal.decrease.circle")
                }
            }
            .padding()

            Divider()

            // 自动生成配置卡片
            if appState.userConfig.autoGenerate {
                AutoGenerateConfigCard(config: appState.userConfig)
                    .padding(.horizontal)
                    .padding(.top, 12)
            }

            // 播客列表
            if filteredPodcasts.isEmpty && schedulerService.generatingCategories.isEmpty {
                EmptyStateView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 20, pinnedViews: [.sectionHeaders]) {
                        // 显示正在生成的分类占位符
                        ForEach(Array(schedulerService.generatingCategories).sorted(), id: \.self) { category in
                            Section {
                                GeneratingPlaceholder(category: category)
                            } header: {
                                HStack {
                                    Text(category)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text("生成中...")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Color(NSColor.controlBackgroundColor))
                            }
                        }

                        // 显示已有的播客分组
                        ForEach(groupedPodcasts.keys.sorted(), id: \.self) { category in
                            Section {
                                ForEach(displayedPodcasts(for: category)) { podcast in
                                    PodcastCard(podcast: podcast, onPlay: {
                                        playPodcast(podcast)
                                    })
                                }
                            } header: {
                                CategoryHeader(
                                    category: category,
                                    displayedCount: displayedPodcasts(for: category).count,
                                    totalCount: groupedPodcasts[category]?.count ?? 0,
                                    isExpanded: expandedCategories.contains(category),
                                    onToggle: {
                                        toggleCategory(category)
                                    }
                                )
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    private var filteredPodcasts: [Podcast] {
        switch selectedFilter {
        case .all:
            return podcasts
        case .notStarted:
            return podcasts.filter { $0.playStatus == .notStarted }
        case .inProgress:
            return podcasts.filter { $0.playStatus == .inProgress }
        case .completed:
            return podcasts.filter { $0.playStatus == .completed }
        }
    }

    private var groupedPodcasts: [String: [Podcast]] {
        Dictionary(grouping: filteredPodcasts) { $0.displayCategory }
    }

    /// 获取指定分类要显示的播客列表
    private func displayedPodcasts(for category: String) -> [Podcast] {
        guard let podcasts = groupedPodcasts[category] else { return [] }

        // 如果分类已展开或播客数量不超过默认数量，显示全部
        if expandedCategories.contains(category) || podcasts.count <= defaultDisplayCount {
            return podcasts
        }

        // 否则只显示最新的几个
        return Array(podcasts.prefix(defaultDisplayCount))
    }

    /// 切换分类的展开/收起状态
    private func toggleCategory(_ category: String) {
        if expandedCategories.contains(category) {
            expandedCategories.remove(category)
        } else {
            expandedCategories.insert(category)
        }
    }

    private func playPodcast(_ podcast: Podcast) {
        guard let audioPath = podcast.audioFilePath else { return }
        let audioURL = URL(fileURLWithPath: audioPath)
        audioPlayer.loadAndPlay(podcast: podcast, audioURL: audioURL)
    }
}

struct PodcastCard: View {
    let podcast: Podcast
    let onPlay: () -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题和话题
            HStack(alignment: .top, spacing: 12) {
                // 播放按钮
                Button(action: onPlay) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("播放播客")

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(podcast.title)
                            .font(.headline)

                        Spacer()

                        // 分组标签
                        Text(podcast.displayCategory)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundColor(.accentColor)
                            .cornerRadius(4)
                    }

                    Text(podcast.topics.joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // 时长和日期
            HStack {
                Text(podcast.formattedDuration)
                Text("·")
                Text(podcast.createdAt, format: .dateTime.year().month().day().hour().minute())
                Text("·")
                Text("\(podcast.length) 分钟")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            // 播放进度
            ProgressView(value: podcast.playProgress)
                .tint(progressColor(for: podcast.playStatus))

            HStack {
                Text("\(Int(podcast.playProgress * 100))% \(podcast.playStatus.displayText)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: { isExpanded.toggle() }) {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "收起详情" : "查看详情")
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }

            // 详细信息（可展开）
            if isExpanded {
                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    // RSS 来源文章
                    if !podcast.sourceArticles.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("RSS 来源文章 (\(podcast.sourceArticles.count) 篇)")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            ScrollView {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(Array(podcast.sourceArticles.enumerated()), id: \.offset) { index, article in
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text("\(index + 1).")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)

                                                Text(article.title)
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                            }

                                            if !article.description.isEmpty {
                                                Text(article.description)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(2)
                                            }

                                            HStack {
                                                Text(article.formattedPubDate)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)

                                                Spacer()

                                                if let url = URL(string: article.link) {
                                                    Link("查看原文", destination: url)
                                                        .font(.caption)
                                                }
                                            }
                                        }
                                        .padding(8)
                                        .background(Color(NSColor.textBackgroundColor))
                                        .cornerRadius(6)
                                    }
                                }
                            }
                            .frame(maxHeight: 200)
                        }
                    }

                    // 配置信息
                    VStack(alignment: .leading, spacing: 4) {
                        Text("播客配置")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        HStack {
                            Label("风格", systemImage: "theatermasks")
                            Text(podcast.hostStyle)
                            Spacer()
                            Label("深度", systemImage: "chart.bar")
                            Text(podcast.contentDepth)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }

                    // 音频文件信息
                    if let audioPath = podcast.audioFilePath {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("音频文件")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Text(audioPath)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)

                            // 检查文件是否存在
                            if FileManager.default.fileExists(atPath: audioPath) {
                                Label("文件存在", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                         Label("文件不存在", systemImage: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    // 播客文稿
                    VStack(alignment: .leading, spacing: 4) {
                        Text("播客文稿")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        ScrollView {
                            Text(podcast.scriptContent)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                        }
                        .frame(maxHeight: 300)
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private func progressColor(for status: PlayStatus) -> Color {
        switch status {
        case .notStarted: return .gray
        case .inProgress: return .blue
        case .completed: return .green
        }
    }
}

/// 分类头部组件
struct CategoryHeader: View {
    let category: String
    let displayedCount: Int
    let totalCount: Int
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Text(category)
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                // 显示计数和提示
                if totalCount > 3 {
                    if isExpanded {
                        Text("收起")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    } else {
                        Text("显示全部 \(totalCount) 个")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                } else if totalCount > 0 {
                    Text("\(totalCount) 个播客")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // 展开/收起图标
                if totalCount > 3 {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "headphones")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("还没有播客")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("点击下方按钮生成你的第一个播客")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

enum FilterOption: String, CaseIterable {
    case all = "全部"
    case notStarted = "未听"
    case inProgress = "进行中"
    case completed = "已听完"
}

/// 自动生成配置卡片
struct AutoGenerateConfigCard: View {
    let config: UserConfig

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 24))
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 4) {
                Text("自动生成已启用")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 8) {
                    Text(config.autoGenerateFrequency.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("·")
                        .foregroundColor(.secondary)

                    Text(config.autoGenerateTime)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !config.autoGenerateTopics.isEmpty {
                        Text("·")
                            .foregroundColor(.secondary)

                        Text("\(config.autoGenerateTopics.count) 个话题")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // 下次生成时间
            VStack(alignment: .trailing, spacing: 4) {
                Text("下次生成")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(nextGenerateTime)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }

    private var nextGenerateTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        guard let targetTime = formatter.date(from: config.autoGenerateTime) else {
            return config.autoGenerateTime
        }

        let calendar = Calendar.current
        let now = Date()

        // 获取今天的目标时间
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        let targetComponents = calendar.dateComponents([.hour, .minute], from: targetTime)
        components.hour = targetComponents.hour
        components.minute = targetComponents.minute

        guard var nextDate = calendar.date(from: components) else {
            return config.autoGenerateTime
        }

        // 如果今天的时间已过，计算下一个符合条件的日期
        if nextDate <= now {
            nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
        }

        // 根据频率调整
        switch config.autoGenerateFrequency {
        case .daily:
            break // 每天都生成，不需要调整
        case .weekdays:
            // 如果是周末，跳到下周一
            while calendar.isDateInWeekend(nextDate) {
                nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
            }
        case .weekends:
            // 如果是工作日，跳到周末
            while !calendar.isDateInWeekend(nextDate) {
                nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
            }
        case .custom:
            break // 自定义逻辑暂不实现
        }

        // 格式化显示
        let outputFormatter = DateFormatter()
        if calendar.isDateInToday(nextDate) {
            return "今天 \(config.autoGenerateTime)"
        } else if calendar.isDateInTomorrow(nextDate) {
            return "明天 \(config.autoGenerateTime)"
        } else {
            outputFormatter.dateFormat = "MM-dd HH:mm"
            return outputFormatter.string(from: nextDate)
        }
    }
}

/// 生成中占位符
struct GeneratingPlaceholder: View {
    let category: String

    var body: some View {
        VStack(spacing: 16) {
            // 加载动画
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle())

            VStack(spacing: 8) {
                Text("正在生成\(category)播客")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("正在获取内容并生成音频，请稍候...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

#Preview {
    PodcastListView()
        .environmentObject(AudioPlayer())
        .environmentObject(AppState())
        .environmentObject(SchedulerService())
        .modelContainer(for: [Podcast.self])
}
