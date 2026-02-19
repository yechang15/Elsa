# MemoryManager 实现总结

## 已完成的工作

### 1. 核心服务实现
- ✅ 创建 `MemoryManager.swift` 服务
  - 文件读写功能（profile.md, preferences.md, goals.md, memory_summary.md）
  - 从行为数据生成偏好设置
  - 生成记忆摘要
  - 记忆统计功能

### 2. 数据模型
- ✅ 已有完整的行为追踪模型：
  - `UserBehaviorEvent` - 用户行为事件
  - `PlaybackSession` - 播放会话
  - `ContentInteraction` - 内容交互
  - `TopicPreference` - 话题偏好

### 3. 系统集成
- ✅ 在 `PodcastApp.swift` 中初始化 MemoryManager
- ✅ 将 MemoryManager 注入到环境对象
- ✅ 在 `PodcastService` 中添加 memoryManager 属性
- ✅ 在生成播客时注入用户记忆到 LLM prompt

### 4. LLM 集成
- ✅ 修改 `LLMService.generatePodcastScript` 添加 `userMemory` 参数
- ✅ 在 prompt 中注入用户偏好记忆
- ✅ PodcastService 在生成播客时自动读取记忆摘要

### 5. UI 界面
- ✅ 创建 `MemoryView.swift` 记忆管理界面
  - 查看四种记忆文件
  - 从行为数据生成偏好
  - 查看记忆统计
- ✅ 添加到导航栏（"用户记忆"）

### 6. 并发问题修复
- ✅ 修复 AudioPlayer 中 BehaviorTracker 的并发调用问题
  - 所有 BehaviorTracker 调用改为 `Task { @MainActor in }`

## 使用方式

### 1. 查看记忆
在应用侧边栏点击"用户记忆"，可以查看：
- 摘要（memory_summary.md）
- 偏好设置（preferences.md）
- 用户画像（profile.md）
- 目标（goals.md）

### 2. 生成偏好
在记忆界面点击"从行为数据生成"，系统会：
1. 读取 TopicPreference 数据
2. 读取最近 20 次 PlaybackSession
3. 生成结构化的偏好设置文档

### 3. 自动应用到播客生成
当生成播客时，系统会自动：
1. 读取 memory_summary.md
2. 注入到 LLM prompt
3. LLM 根据用户偏好调整内容

## 记忆文件位置

```
~/Library/Containers/[AppID]/Data/Documents/memory/
├── profile.md
├── preferences.md
├── goals.md
└── memory_summary.md
```

## 下一步工作

### Phase 2（短期）
- [ ] 实现自动更新触发机制
  - 每 10 次播放后自动更新偏好
  - 话题偏好分数变化 ±20 分时更新
- [ ] 实现 memory_summary.md 的自动生成
  - 基于其他三个文件生成摘要
- [ ] 添加记忆更新通知

### Phase 3（中期）
- [ ] 完善 profile.md 和 goals.md 的更新逻辑
  - 通过聊天对话提取用户画像
  - 识别用户目标变化
- [ ] 添加记忆压缩功能
  - 当文件超过 800 字时自动压缩
- [ ] 优化更新频率和触发条件

### Phase 4（长期）
- [ ] 添加记忆可视化
  - 话题偏好雷达图
  - 播放行为时间线
- [ ] 实现记忆导出/导入
- [ ] 支持多设备同步（iCloud）

## 技术要点

### 1. 文件存储
使用 Markdown 格式存储记忆，优点：
- 人类可读
- 易于编辑
- 直接注入 LLM prompt
- 版本控制友好

### 2. 数据流
```
用户行为 → BehaviorTracker → SwiftData
                                    ↓
                            MemoryManager 分析
                                    ↓
                            生成/更新 MD 文件
                                    ↓
                            PodcastService 读取
                                    ↓
                            注入 LLM Prompt
                                    ↓
                            生成个性化播客
```

### 3. 并发安全
- MemoryManager 标记为 `@MainActor`
- 所有文件 I/O 操作在主线程
- BehaviorTracker 调用使用 `Task { @MainActor in }`

## 参考文档

- [Memory功能设计方案.md](./Memory功能设计方案.md)
- [用户行为追踪与推荐系统设计.md](./用户行为追踪与推荐系统设计.md)
- [BehaviorTracker使用指南.md](./BehaviorTracker使用指南.md)
