# BehaviorTracker 使用指南

## 快速开始

BehaviorTracker 是用户行为追踪的核心服务，已经集成到应用的各个关键位置。

### 访问 BehaviorTracker

在 SwiftUI View 中：
```swift
@EnvironmentObject var behaviorTracker: BehaviorTracker
```

在 Service 中：
```swift
var behaviorTracker: BehaviorTracker?
```

---

## API 参考

### 播放行为追踪

#### 开始播放会话
```swift
behaviorTracker.startPlaybackSession(
    podcast: podcast,
    startPosition: 0.0  // 可选，默认从头开始
)
```

#### 更新播放进度
```swift
behaviorTracker.updatePlaybackProgress(
    currentPosition: currentTime,
    playbackSpeed: playbackRate
)
```

#### 记录暂停
```swift
behaviorTracker.recordPause()
```

#### 记录恢复播放
```swift
behaviorTracker.recordResume()
```

#### 记录跳转
```swift
behaviorTracker.recordSeek(
    from: oldPosition,
    to: newPosition
)
```

#### 记录播放速度变化
```swift
behaviorTracker.recordSpeedChange(speed: 1.5)
```

#### 结束播放会话
```swift
behaviorTracker.endPlaybackSession(finalPosition: currentTime)
```

---

### 内容交互追踪

#### 记录播客查看
```swift
behaviorTracker.recordPodcastView(
    podcast: podcast,
    sourceScreen: "home"  // 可选：来源页面
)
```

#### 记录播客生成
```swift
behaviorTracker.recordPodcastGeneration(
    podcast: podcast,
    config: [
        "length": 15,
        "contentDepth": "深度分析",
        "hostStyle": "轻松闲聊"
    ]
)
```

---

### 话题管理追踪

#### 记录添加话题
```swift
behaviorTracker.recordTopicAdd(topicName: "Swift 开发")
```

#### 记录删除话题
```swift
behaviorTracker.recordTopicRemove(topicName: "Swift 开发")
```

#### 记录话题优先级变化
```swift
behaviorTracker.recordTopicPriorityChange(
    topicName: "Swift 开发",
    oldPriority: 5,
    newPriority: 10
)
```

---

### 聊天交互追踪

#### 记录聊天消息
```swift
behaviorTracker.recordChatMessage(
    message: chatMessage,
    extractedTopics: ["Swift", "iOS", "开发"]  // 可选：提取的话题
)
```

---

## 查询 API

### 获取话题偏好列表
```swift
let preferences = behaviorTracker.getTopicPreferences(limit: 20)

for preference in preferences {
    print("话题: \(preference.topicName)")
    print("偏好评分: \(preference.preferenceScore)")
    print("偏好等级: \(preference.preferenceLevel)")
    print("平均完播率: \(preference.averageCompletionRate)")
    print("总播放次数: \(preference.totalPlays)")
    print("---")
}
```

### 获取最近的播放会话
```swift
let sessions = behaviorTracker.getRecentPlaybackSessions(limit: 50)

for session in sessions {
    print("播客: \(session.podcastTitle)")
    print("完播率: \(Int(session.completionRate * 100))%")
    print("兴趣等级: \(session.interestLevel)")
    print("暂停次数: \(session.pauseCount)")
    print("跳转次数: \(session.seekCount)")
    print("---")
}
```

### 获取用户行为事件
```swift
// 获取所有事件
let allEvents = behaviorTracker.getBehaviorEvents(limit: 100)

// 获取特定类型的事件
let playEvents = behaviorTracker.getBehaviorEvents(
    eventType: .playStart,
    limit: 50
)
```

---

## 实现推荐功能示例

### 1. 获取推荐话题

```swift
func getRecommendedTopics() -> [String] {
    let preferences = behaviorTracker.getTopicPreferences(limit: 20)

    // 过滤出感兴趣的话题（评分 >= 40）
    let interestedTopics = preferences
        .filter { $0.preferenceScore >= 40 }
        .map { $0.topicName }

    return interestedTopics
}
```

### 2. 智能选择生成话题

```swift
func selectTopicsForGeneration(count: Int = 3) -> [String] {
    let preferences = behaviorTracker.getTopicPreferences(limit: 20)

    // 综合考虑偏好评分和最近活跃度
    let scoredTopics = preferences.map { preference -> (String, Double) in
        var score = preference.preferenceScore

        // 最近7天有活动，加分
        if let lastDate = preference.lastInteractionDate,
           Date().timeIntervalSince(lastDate) < 7 * 86400 {
            score += 10
        }

        // 生成转化率高，加分
        if preference.generationConversionRate > 0.8 {
            score += 5
        }

        return (preference.topicName, score)
    }

    // 按评分排序，取前N个
    return scoredTopics
        .sorted { $0.1 > $1.1 }
        .prefix(count)
        .map { $0.0 }
}
```

### 3. 分析用户收听模式

```swift
func analyzeUserListeningPattern() -> ListeningPattern {
    let sessions = behaviorTracker.getRecentPlaybackSessions(limit: 100)

    // 计算平均完播率
    let avgCompletionRate = sessions.map { $0.completionRate }.reduce(0, +) / Double(sessions.count)

    // 计算平均播放速度
    let avgSpeed = sessions.map { $0.playbackSpeed }.reduce(0, +) / Double(sessions.count)

    // 计算平均暂停次数
    let avgPauseCount = Double(sessions.map { $0.pauseCount }.reduce(0, +)) / Double(sessions.count)

    // 判断用户类型
    if avgCompletionRate > 0.8 && avgSpeed <= 1.0 && avgPauseCount > 3 {
        return .deepLearner  // 深度学习者
    } else if avgCompletionRate > 0.5 && avgSpeed >= 1.5 {
        return .fastBrowser  // 快速浏览者
    } else {
        return .selectiveListener  // 选择性收听者
    }
}

enum ListeningPattern {
    case deepLearner
    case fastBrowser
    case selectiveListener
}
```

### 4. 根据用户模式调整生成参数

```swift
func getOptimalGenerationConfig() -> (length: Int, depth: String, style: String) {
    let pattern = analyzeUserListeningPattern()

    switch pattern {
    case .deepLearner:
        return (length: 20, depth: "深度分析", style: "严肃分析")

    case .fastBrowser:
        return (length: 10, depth: "快速浏览", style: "轻松闲聊")

    case .selectiveListener:
        return (length: 15, depth: "快速浏览", style: "轻松闲聊")
    }
}
```

---

## 数据可视化示例

### 1. 收听统计

```swift
struct ListeningStatsView: View {
    @EnvironmentObject var behaviorTracker: BehaviorTracker

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("我的收听统计")
                .font(.title)
                .fontWeight(.bold)

            // 总收听时长
            let sessions = behaviorTracker.getRecentPlaybackSessions(limit: 1000)
            let totalMinutes = sessions.map { $0.playedDuration }.reduce(0, +) / 60

            StatCard(
                title: "总收听时长",
                value: "\(totalMinutes) 分钟",
                icon: "clock.fill"
            )

            // 平均完播率
            let avgCompletion = sessions.map { $0.completionRate }.reduce(0, +) / Double(sessions.count)

            StatCard(
                title: "平均完播率",
                value: "\(Int(avgCompletion * 100))%",
                icon: "chart.bar.fill"
            )

            // 最喜欢的话题
            let topTopics = behaviorTracker.getTopicPreferences(limit: 5)

            VStack(alignment: .leading, spacing: 8) {
                Text("最喜欢的话题")
                    .font(.headline)

                ForEach(topTopics, id: \.id) { preference in
                    HStack {
                        Text(preference.topicName)
                        Spacer()
                        Text("\(Int(preference.preferenceScore))分")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
    }
}
```

### 2. 话题偏好雷达图

```swift
struct TopicPreferenceRadarView: View {
    @EnvironmentObject var behaviorTracker: BehaviorTracker

    var body: some View {
        let preferences = behaviorTracker.getTopicPreferences(limit: 6)

        // 使用 Charts 框架绘制雷达图
        // 这里需要实现具体的雷达图绘制逻辑
    }
}
```

---

## 最佳实践

### 1. 性能优化

- 播放进度更新不要太频繁（建议0.5秒一次）
- 批量操作使用事务
- 定期清理旧数据

```swift
// 批量操作示例
modelContext.transaction {
    for topic in topics {
        behaviorTracker.recordTopicAdd(topicName: topic)
    }
}
```

### 2. 错误处理

```swift
// BehaviorTracker 的方法都是安全的，不会抛出错误
// 但建议检查关键数据是否存在

if let currentSession = behaviorTracker.currentPlaybackSession {
    // 有活跃的播放会话
} else {
    // 没有活跃的播放会话
}
```

### 3. 数据一致性

- 确保每次 startPlaybackSession 都有对应的 endPlaybackSession
- 在应用退出时保存未完成的会话

```swift
// 在应用退出时
func applicationWillTerminate() {
    if let session = behaviorTracker.currentPlaybackSession {
        behaviorTracker.endPlaybackSession(finalPosition: audioPlayer.currentTime)
    }
}
```

---

## 调试技巧

### 1. 打印当前状态

```swift
func debugBehaviorTracker() {
    print("=== BehaviorTracker 状态 ===")

    // 当前播放会话
    if let session = behaviorTracker.currentPlaybackSession {
        print("当前播放: \(session.podcastTitle)")
        print("完播率: \(Int(session.completionRate * 100))%")
    } else {
        print("无活跃播放会话")
    }

    // 话题偏好
    let preferences = behaviorTracker.getTopicPreferences(limit: 5)
    print("\n话题偏好 Top 5:")
    for (index, pref) in preferences.enumerated() {
        print("\(index + 1). \(pref.topicName): \(Int(pref.preferenceScore))分")
    }

    // 最近事件
    let events = behaviorTracker.getBehaviorEvents(limit: 10)
    print("\n最近10个事件:")
    for event in events {
        print("- \(event.eventType) @ \(event.timestamp)")
    }
}
```

### 2. 验证数据完整性

```swift
func validateDataIntegrity() {
    let sessions = behaviorTracker.getRecentPlaybackSessions(limit: 100)

    // 检查是否有异常的完播率
    let invalidSessions = sessions.filter { $0.completionRate > 1.0 || $0.completionRate < 0 }
    if !invalidSessions.isEmpty {
        print("⚠️ 发现 \(invalidSessions.count) 个异常会话")
    }

    // 检查是否有未结束的会话
    let unfinishedSessions = sessions.filter { $0.endTime == nil }
    if !unfinishedSessions.isEmpty {
        print("⚠️ 发现 \(unfinishedSessions.count) 个未结束的会话")
    }
}
```

---

## 常见问题

### Q: 如何清除所有行为数据？

```swift
func clearAllBehaviorData() {
    // 删除所有 UserBehaviorEvent
    let events = try? modelContext.fetch(FetchDescriptor<UserBehaviorEvent>())
    events?.forEach { modelContext.delete($0) }

    // 删除所有 PlaybackSession
    let sessions = try? modelContext.fetch(FetchDescriptor<PlaybackSession>())
    sessions?.forEach { modelContext.delete($0) }

    // 删除所有 ContentInteraction
    let interactions = try? modelContext.fetch(FetchDescriptor<ContentInteraction>())
    interactions?.forEach { modelContext.delete($0) }

    // 删除所有 TopicPreference
    let preferences = try? modelContext.fetch(FetchDescriptor<TopicPreference>())
    preferences?.forEach { modelContext.delete($0) }

    try? modelContext.save()
}
```

### Q: 如何导出用户数据？

```swift
func exportUserData() -> [String: Any] {
    let preferences = behaviorTracker.getTopicPreferences(limit: 100)
    let sessions = behaviorTracker.getRecentPlaybackSessions(limit: 100)

    return [
        "topicPreferences": preferences.map { [
            "topicName": $0.topicName,
            "preferenceScore": $0.preferenceScore,
            "totalPlays": $0.totalPlays,
            "averageCompletionRate": $0.averageCompletionRate
        ]},
        "playbackSessions": sessions.map { [
            "podcastTitle": $0.podcastTitle,
            "completionRate": $0.completionRate,
            "playedDuration": $0.playedDuration,
            "startTime": $0.startTime.ISO8601Format()
        ]}
    ]
}
```

### Q: 如何处理多设备同步？

目前数据存储在本地，如果需要多设备同步，可以考虑：
1. 使用 iCloud + CloudKit
2. 定期导出/导入数据
3. 实现自定义同步服务

---

## 更新日志

### v1.0.0 (2024-02-19)
- 初始版本
- 实现核心数据模型
- 集成到播放器、聊天、话题管理
- 基础查询 API

### 未来计划
- v1.1.0: 添加数据可视化组件
- v1.2.0: 实现推荐算法
- v1.3.0: 添加用户画像功能
- v2.0.0: 支持多设备同步
