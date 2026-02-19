import SwiftUI

// 文稿视图
struct ScriptView: View {
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
