# LLM 版本 generateSummary 实现总结

## 实现内容

实现了 `MemoryManager.generateSummary()` 的 LLM 智能压缩版本，支持自动降级到基础版本。

## 核心特性

### 1. 智能降级机制

```swift
func generateSummary() async throws -> String {
    // 如果有 LLM 服务，使用智能压缩
    if let llmService = llmService {
        return try await generateSummaryWithLLM(...)
    }

    // 否则使用基础版本（从行为数据提取）
    return try await generateSummaryBasic()
}
```

**优点**：
- 有 LLM 配置时：生成高质量、个性化的摘要
- 无 LLM 配置时：仍能工作，从行为数据提取基础信息

### 2. LLM 版本特性

**输入**：
- preferences.md（播客偏好）
- profile.md（用户画像，可选）
- goals.md（当前目标，可选）

**处理**：
- 构建结构化 prompt，要求 LLM 压缩为 300 字以内
- 明确输出格式：一句话画像 + 核心特征 + 生成建议
- 重点保留：兴趣话题、内容偏好、当前目标、明确排斥

**输出**：
```markdown
# User Memory Summary

## 一句话画像
30多岁的互联网产品经理，理性思维，正在准备 AI 方向创业...

## 核心特征
- **职业背景**：产品经理，有技术背景
- **当前目标**：学习 AI 技术，准备创业
- **内容偏好**：AI、创业、产品设计（深度分析）
- **形式偏好**：双人对话，15-20分钟，1.5x速度
- **风格偏好**：理性、数据驱动、高信息密度
- **明确排斥**：娱乐八卦、鸡汤、伪科学

## 生成建议
- 话题选择：优先 AI 技术应用、创业案例、产品方法论
- 内容深度：中高深度，避免浅层科普
- 对话风格：理性讨论，适度幽默，有数据支撑
- 时长控制：15-20分钟最佳
- 节奏：紧凑，信息密度高，减少冗余

最后更新：2024-02-20
```

### 3. 基础版本特性

当没有 LLM 服务时，从行为数据直接提取：
- 从 TopicPreference 提取高分话题（≥70分）
- 从 PlaybackSession 提取平均时长、播放速度、完播率
- 生成简化的摘要（固定模板）

## 代码变更

### 1. MemoryManager.swift
- ✅ 添加 `llmService: LLMService?` 属性
- ✅ 重构 `generateSummary()` 为智能降级版本
- ✅ 新增 `generateSummaryWithLLM()` - LLM 智能压缩
- ✅ 新增 `generateSummaryBasic()` - 基础版本

### 2. LLMService.swift
- ✅ 新增 `generateText(prompt:)` 通用方法
- 复用现有的 `callDoubaoAPIStreaming` 和 `callOpenAIAPIStreaming`

### 3. PodcastService.swift
- ✅ 修改 `setupLLM()` 方法，同时注入 llmService 到 memoryManager

### 4. MemoryView.swift
- ✅ 添加"生成摘要"按钮（在 summary 标签页）
- ✅ 新增 `generateSummaryAction()` 方法
- ✅ 显示生成版本提示（LLM 版本 / 基础版本）

## 使用方式

### 手动触发
1. 打开应用，进入"用户记忆"页面
2. 切换到"摘要"标签页
3. 点击"生成摘要"按钮
4. 系统会自动判断：
   - 如果已配置 LLM → 使用 LLM 智能生成
   - 如果未配置 LLM → 使用基础版本生成

### 自动触发
在 `updateMemoryFromBehavior()` 中自动调用：
```swift
func updateMemoryFromBehavior() async throws {
    // 1. 生成偏好设置
    let preferences = try await generatePreferencesFromBehavior()
    try updatePreferences(preferences)

    // 2. 生成摘要（自动选择 LLM 或基础版本）
    let summary = try await generateSummary()
    try updateSummary(summary)
}
```

## 数据流

```
用户点击"生成摘要"
    ↓
MemoryManager.generateSummary()
    ↓
检查 llmService 是否存在？
    ↓
是 → generateSummaryWithLLM()
    ↓
    读取 preferences.md + profile.md + goals.md
    ↓
    构建 prompt（要求 300 字以内）
    ↓
    调用 LLMService.generateText()
    ↓
    返回智能压缩的摘要

否 → generateSummaryBasic()
    ↓
    从 TopicPreference 提取高分话题
    ↓
    从 PlaybackSession 提取播放统计
    ↓
    返回基础版本摘要

    ↓
写入 memory_summary.md
    ↓
下次生成播客时自动读取并注入到 prompt
```

## 优势

1. **智能压缩**：LLM 能理解语义，提取关键信息，生成更自然的摘要
2. **个性化**：根据用户的实际偏好生成针对性建议
3. **自动降级**：无 LLM 时仍能工作，不影响基本功能
4. **节省 token**：摘要控制在 300 字以内，生成播客时注入成本低
5. **易于维护**：清晰的降级逻辑，代码结构清晰

## 测试建议

1. **有 LLM 配置时**：
   - 先生成 preferences.md（从行为数据生成）
   - 再生成 summary.md（LLM 版本）
   - 检查摘要质量和格式

2. **无 LLM 配置时**：
   - 直接生成 summary.md（基础版本）
   - 检查是否能正常工作

3. **生成播客时**：
   - 检查 summary 是否正确注入到 prompt
   - 观察生成的播客是否符合用户偏好

## 后续优化

1. **添加缓存**：避免频繁调用 LLM
2. **增量更新**：只在偏好显著变化时重新生成
3. **多语言支持**：根据用户语言生成对应语言的摘要
4. **版本对比**：保留历史版本，对比摘要变化
