# RSS获取进度显示改进

## 问题

获取RSS内容时，用户只能看到"正在获取RSS内容..."的提示，无法知道具体进度，体验不好。

## 解决方案

添加详细的进度显示，实时显示已获取的RSS源数量。

## 实现

### 1. 修改RSSService

在`fetchMultipleFeeds`方法中添加进度回调：

```swift
/// 批量获取多个RSS源
func fetchMultipleFeeds(
    urls: [String],
    progressHandler: ((Int, Int) -> Void)? = nil  // 新增：进度回调
) async -> [RSSArticle] {
    let totalCount = urls.count
    var completedCount = 0

    return await withTaskGroup(of: (Int, [RSSArticle]).self) { group in
        for (index, url) in urls.enumerated() {
            group.addTask {
                let articles = (try? await self.fetchFeed(url: url)) ?? []
                return (index, articles)
            }
        }

        var allArticles: [RSSArticle] = []
        for await (_, articles) in group {
            completedCount += 1
            allArticles.append(contentsOf: articles)

            // 报告进度
            progressHandler?(completedCount, totalCount)
        }

        return allArticles.sorted { $0.pubDate > $1.pubDate }
    }
}
```

### 2. 修改PodcastService

在调用`fetchMultipleFeeds`时传递进度回调：

```swift
let articles = await rssService.fetchMultipleFeeds(urls: feedURLs) { completed, total in
    Task { @MainActor in
        self.currentStatus = "正在获取RSS内容... (\(completed)/\(total))"
        // 进度从0.1到0.3，根据完成比例计算
        self.generationProgress = 0.1 + (0.2 * Double(completed) / Double(total))
    }
}
```

## 效果

### 修改前
```
正在获取RSS内容...
```
用户不知道进度，只能等待。

### 修改后
```
正在获取RSS内容... (1/5)
正在获取RSS内容... (2/5)
正在获取RSS内容... (3/5)
正在获取RSS内容... (4/5)
正在获取RSS内容... (5/5)
已获取 23 篇文章
```

用户可以清楚地看到：
- 总共需要获取多少个RSS源
- 当前已经获取了多少个
- 实时进度百分比（通过进度条显示）

## 进度计算

RSS获取阶段占总进度的20%（从0.1到0.3）：

```
进度 = 0.1 + (0.2 × 已完成数 / 总数)

示例（5个RSS源）：
- 0/5: 10%
- 1/5: 14%
- 2/5: 18%
- 3/5: 22%
- 4/5: 26%
- 5/5: 30%
```

## 并发获取

RSS源是并发获取的（使用`TaskGroup`），所以：
- 多个RSS源同时下载
- 完成顺序可能不是添加顺序
- 但进度显示是准确的

## 测试

运行测试脚本验证进度显示：

```bash
swift test_rss_progress.swift
```

输出示例：
```
开始获取 5 个RSS源...

✅ 已获取: https://example.com/feed1.xml
📊 进度: 1/5 (20.0%)
✅ 已获取: https://example.com/feed2.xml
📊 进度: 2/5 (40.0%)
✅ 已获取: https://example.com/feed3.xml
📊 进度: 3/5 (60.0%)
✅ 已获取: https://example.com/feed4.xml
📊 进度: 4/5 (80.0%)
✅ 已获取: https://example.com/feed5.xml
📊 进度: 5/5 (100.0%)

✅ 全部完成！
```

## 用户体验改进

1. **透明度提升**：用户知道系统在做什么
2. **心理预期**：用户知道还需要等多久
3. **信心增强**：看到进度在推进，不会以为卡住了
4. **问题定位**：如果某个RSS源很慢，用户可以看到进度停滞

## 未来扩展

可以考虑：
1. 显示每个RSS源的名称（而不只是数量）
2. 显示获取失败的RSS源
3. 允许用户跳过慢速的RSS源
4. 显示每个RSS源的获取时间
