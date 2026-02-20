import SwiftUI

// 文稿视图
struct ScriptView: View {
    let podcast: Podcast
    @EnvironmentObject var audioPlayer: AudioPlayer
    @State private var isFullScreen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 工具栏
            HStack {
                Text("播客文稿")
                    .font(.headline)

                Spacer()

                // 显示段落数量
                if !podcast.segments.isEmpty {
                    Text("\(podcast.segments.count) 段")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Button(action: { isFullScreen.toggle() }) {
                    Label(isFullScreen ? "退出全屏" : "全屏阅读", systemImage: isFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 文稿内容
            if podcast.segments.isEmpty {
                // 如果没有 segments 数据，显示原始文本
                ScrollView {
                    Text(podcast.scriptContent)
                        .font(.body)
                        .lineSpacing(8)
                        .textSelection(.enabled)
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 使用 segments 数据显示，支持高亮
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(podcast.segments) { segment in
                                SegmentRow(
                                    segment: segment,
                                    isCurrentlyPlaying: isCurrentSegment(segment),
                                    isPlaying: audioPlayer.isPlaying && audioPlayer.currentPodcast?.id == podcast.id
                                )
                                .id(segment.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: audioPlayer.currentTime) { _, newTime in
                        // 自动滚动到当前播放的段落
                        if audioPlayer.currentPodcast?.id == podcast.id,
                           let currentSegment = podcast.getCurrentSegment(at: newTime) {
                            withAnimation {
                                proxy.scrollTo(currentSegment.id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }

    private func isCurrentSegment(_ segment: ScriptSegment) -> Bool {
        guard audioPlayer.currentPodcast?.id == podcast.id else {
            return false
        }
        return segment.contains(time: audioPlayer.currentTime)
    }
}

// 段落行组件
struct SegmentRow: View {
    let segment: ScriptSegment
    let isCurrentlyPlaying: Bool
    let isPlaying: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 时间标签
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatTime(segment.startTime))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .monospacedDigit()

                if isCurrentlyPlaying && isPlaying {
                    Image(systemName: "waveform")
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                        .symbolEffect(.variableColor.iterative, isActive: true)
                }
            }
            .frame(width: 50)

            // 内容
            VStack(alignment: .leading, spacing: 4) {
                Text(segment.speaker)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(isCurrentlyPlaying ? .accentColor : .secondary)

                Text(segment.content)
                    .font(.body)
                    .lineSpacing(6)
                    .foregroundColor(isCurrentlyPlaying ? .primary : .secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isCurrentlyPlaying ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isCurrentlyPlaying ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .animation(.easeInOut(duration: 0.3), value: isCurrentlyPlaying)
    }

    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// 旧版本的 ScriptView（用于兼容）
struct LegacyScriptView: View {
    let scriptContent: String
    @State private var isFullScreen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 工具栏
            HStack {
                Text("播客文稿")
                    .font(.headline)

                Spacer()

                Button(action: { isFullScreen.toggle() }) {
                    Label(isFullScreen ? "退出全屏" : "全屏阅读", systemImage: isFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 文稿内容
            ScrollView {
                Text(scriptContent)
                    .font(.body)
                    .lineSpacing(8)
                    .textSelection(.enabled)
                    .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// 来源文章视图
struct SourceArticlesView: View {
    let articles: [SourceArticle]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题
            HStack {
                Text("RSS 来源文章")
                    .font(.headline)

                Spacer()

                Text("\(articles.count) 篇")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 文章列表
            if articles.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("暂无来源文章")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(articles.enumerated()), id: \.offset) { index, article in
                            ArticleCard(article: article, index: index + 1)
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

// 文章卡片
struct ArticleCard: View {
    let article: SourceArticle
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题
            HStack(alignment: .top, spacing: 8) {
                Text("\(index).")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 20, alignment: .leading)

                Text(article.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }

            // 摘要
            if !article.description.isEmpty {
                Text(article.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .padding(.leading, 28)
            }

            // 日期和链接
            HStack {
                Text(article.formattedPubDate)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if let url = URL(string: article.link) {
                    Link(destination: url) {
                        Label("查看原文", systemImage: "arrow.up.right.square")
                            .font(.caption)
                    }
                }
            }
            .padding(.leading, 28)
        }
        .padding(12)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
    }
}
