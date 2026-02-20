# 工具与技能（Tools & Skills）设计文档

## 一、核心原则与目标

**系统定位**：高度可扩展的「工具 + 编排」架构。播客是其中一个较重的工具；日历、邮箱、天气等作为可灵活接入的轻量工具，通过统一的 `AgentTool` 协议、通过 Skills 按需组合，最终结果**统一通过播客与聊天**透传给用户。

- **可扩展**：新工具（如笔记、待办、RSS）可插拔接入，不改写核心编排逻辑。
- **按需组合**：由 Skills 决定在什么场景下启用哪些工具、如何组合结果。
- **逐次按需加载**：工具、Skill 配置、以及具体要拉取的数据，都在「真正被用到的那一次」才加载或调用，避免启动时全量加载、全量拉权、全量拉数（详见第六节）。
- **透传一致**：无论背后调用了多少工具，用户只面对「播客」和「聊天」两种形态。

---

## 二、整体架构

```
                    ┌─────────────────────────────────────────┐
                    │            透传层（用户可见）              │
                    │    播客 (Podcast)  │  聊天 (Chat)        │
                    └─────────────────┬───────────────────────┘
                                      │
                    ┌─────────────────┴───────────────────────┐
                    │              Skills 层                    │
                    │  何时用谁、如何组合、优先级、兜底策略       │
                    └─────────────────┬───────────────────────┘
                                      │
                    ┌─────────────────┴───────────────────────┐
                    │        工具层（AgentTool 协议）            │
                    │  统一接口、工具注册、调用、结果归一化       │
                    └─────────────────┬───────────────────────┘
                                      │
        ┌─────────────┬───────────────┬───────────────┬─────────────┬─────────────┐
        │             │               │               │             │             │
   ┌────▼────┐   ┌────▼────┐   ┌─────▼─────┐   ┌─────▼─────┐  ┌────▼────┐  ┌────▼────┐
   │ 播客    │   │ 日历    │   │ 天气      │   │ 邮箱      │  │ RSS     │  │ 其他…   │
   │ (重工具)│   │ (Tool)  │   │ (Tool)    │   │ (Tool)    │  │ (Tool)  │  │ (可插拔)│
   └─────────┘   └─────────┘   └───────────┘   └───────────┘  └─────────┘  └─────────┘
                    工具实现（In-App Adapter / 未来可接 MCP Server）
```

- **工具层**：播客、日历、天气、邮箱等，每个实现 `AgentTool` 协议，暴露统一的名称、描述、输入输出。
- **Skills 层**：配置与逻辑，决定在「生成播客 / 推荐 / 聊天 / 播放前」等场景下，调用哪些工具、以什么顺序、如何把多工具结果合并成一份上下文。
- **透传层**：播客 + 聊天。所有组合后的信息最终只通过这两类出口呈现。

> **当前实现方式**：所有工具均为 **In-App Adapter**（直接调系统 API 或 HTTP），不依赖任何 MCP Server 进程。未来如需接入社区工具或做多端共享，可通过 `MCPToolAdapter` 包装远程 MCP Server，对 Skills 层透明。

---

## 三、工具（Tools）清单

| 工具 id | 名称 | 能力摘要 | 典型 Skills 使用 |
|---------|------|----------|------------------|
| **podcast** | 播客 | 生成、推荐、播放；可拆为 `podcast_generate`、`podcast_recommend` 等子能力 | 消费其他工具合并后的上下文，产出播客 |
| **calendar** | 日历 | 今日/本周事件、会议、空闲时段 | 推荐下生成播客、聊天问「今天有什么会」等 |
| **weather** | 天气 | 当前/短期天气、温度、降水、摘要 | 推荐下生成播客、聊天问「天气怎样」等 |
| **email** | 邮箱 | 未读条数、高优先级、摘要 | 推荐下生成播客、聊天问「多少未读邮件」等 |
| **rss** | RSS | 订阅源最新文章/摘要 | 推荐下生成播客（资讯素材）、聊天问「最近有什么新闻」等 |
| *(扩展)* | 其他 | 笔记、待办等，按需接入 | 新场景新 Skill 引用即可 |

---

## 四、AgentTool 协议

每个工具实现同一套协议，Skills 层无需关心底层是系统 API、HTTP 调用还是未来的 MCP Server：

```swift
protocol AgentTool {
    var name: String { get }           // 工具 id，如 "weather"
    var description: String { get }    // 告诉编排引擎这个工具做什么
    func execute(params: [String: Any]) async throws -> String  // 返回结构化文本
}
```

**工具描述示例**（供 Skills 编排使用）：

```yaml
# 日历工具
id: calendar
description: 读取用户日程，提供今日/本周事件、会议、空闲时段
inputs:
  - range: today | week
  - calendar_ids: optional
output: events: [{ title, start, end, all_day }]

# 天气工具
id: weather
description: 当前及短期天气，支持位置
inputs:
  - location: optional
  - range: now | today | 3day
output: temp, condition, precipitation, summary

# 邮箱工具
id: email
description: 未读摘要、高优先级邮件条数
inputs:
  - scope: unread_count | summary
output: unread_count, high_priority_count, summary_text

# RSS 工具
id: rss
description: 用户订阅的 RSS 源最新内容
inputs:
  - feed_ids: optional
  - limit: number
  - range: latest | today
output: items: [{ title, summary, link, published_at }]
```

新工具接入时，只需实现 `AgentTool` 协议并在工具注册表中登记，即可被 Skills 使用。

---

## 五、Skills 设计

### 5.1 Skills 的定位

**Skills = 应用内的编排与策略层**。本应用中「在什么场景下、用哪些工具、如何组合、如何影响播客与聊天」的配置与规则。

- **输入**：当前场景（如：用户点击「生成播客」、打开聊天、进入首页推荐）、用户意图、已有 Memory/行为数据。
- **输出**：本轮要调用的工具列表、参数、优先级，以及如何把各工具输出合并成一份「情境上下文」，交给播客生成/推荐或聊天。

### 5.2 Skill 的结构

每条 Skill 描述「一类场景」下的工具使用策略：

```yaml
# skills/context_for_generation.yaml
id: context_for_generation
name: 生成播客时的情境上下文
description: 在用户请求生成播客时，拉取日历、天气、邮箱摘要，供生成脚本参考

triggers:
  - scene: podcast_generate
  - scene: podcast_recommend

tools:
  - tool: calendar
    params: { range: today }
    required: false
  - tool: weather
    params: { range: today }
    required: false
  - tool: email
    params: { scope: unread_count }
    required: false

merge_policy: concat_summary   # 合并为一段情境摘要
output_to: [ prompt_context ]  # 注入到生成/推荐的 prompt
```

- **triggers**：哪些场景会激活这条 skill。
- **tools**：调用的工具及默认参数；`required: false` 表示该工具不可用时仍可继续。
- **merge_policy**：多工具结果如何合并（如拼接摘要、结构化块等）。
- **output_to**：合并后的上下文注入到哪里（生成 prompt、推荐模型、聊天上下文等）。

### 5.3 按需组合

- **不同场景可挂不同 Skills**：例如「生成播客」用 `context_for_generation`（日历+天气+邮件），「晨间简报」可能再加 RSS、待办等。
- **同一场景可多条 Skill**：按优先级或条件（如「仅在工作日拉日历」）决定是否执行。
- **播客作为工具**：当场景是「用户问：给我讲一下今天日程」时，可能先调日历 tool，再由 Skill 决定用「聊天」直接回复，或再调播客工具生成一段语音摘要。

### 5.4 Skills 的存储与加载

- **配置化**：Skills 以 YAML/JSON 文件存在，便于版本管理与扩展。
- **目录建议**：`skills/` 下按场景或能力分文件。
- **按需加载**：只加载与当前场景匹配的 Skill，不必在启动时解析全部 skill 文件。
- **运行时**：`SkillsEngine` 根据当前场景解析并执行匹配的 Skills，再按 `merge_policy` 与 `output_to` 注入透传层。

### 5.5 完整 Skills 清单

| Skill id | 名称 | 触发场景 | 使用工具 | 输出形态 |
|----------|------|----------|----------|----------|
| `context_for_generation` | 生成时情境上下文 | podcast_generate, podcast_recommend | calendar, weather, email | prompt_context |
| `morning_briefing` | 晨间简报 | 定时（早晨）/ 手动 | weather(today), calendar(today), rss(latest), email(unread) | 播客 |
| `commute_podcast` | 通勤播客 | 用户意图 / 定时 | rss, calendar(today_remaining) | 播客（短，5-10 min）|
| `meeting_prep` | 会议准备 | 日历事件前 30 min | calendar(event), rss(related), memory | 播客 或 聊天 |
| `weekly_review` | 周报播客 | 定时（周五/周日）/ 手动 | calendar(week), rss(week), listening_history | 播客 |
| `smart_recommend` | 智能推荐 | 首页打开 / 空闲 | memory, behavior_tracker, rss, calendar, weather | 推荐列表 |
| `chat_context_tools` | 聊天工具上下文 | chat（意图识别） | calendar, weather, email, rss（按意图选子集）| 聊天 |
| `topic_deep_dive` | 话题深挖 | 用户指定话题 | rss(topic), memory | 播客（长，深度）|
| `news_digest` | 新闻摘要 | 手动 / 定时 | rss(all_feeds) | 播客 |

**补充示例：**

```yaml
# skills/morning_briefing.yaml
id: morning_briefing
name: 晨间简报
triggers:
  - scene: scheduled
    condition: time >= "07:00" AND time <= "09:00"
  - scene: manual
    intent: morning_briefing
tools:
  - tool: weather
    params: { range: today }
    required: false
  - tool: calendar
    params: { range: today }
    required: false
  - tool: rss
    params: { range: latest, limit: 5 }
    required: true
  - tool: email
    params: { scope: unread_count }
    required: false
merge_policy: structured_briefing
output_to: [ podcast_generate ]
podcast_config:
  length: 5
  style: casual

---

# skills/meeting_prep.yaml
id: meeting_prep
name: 会议准备
triggers:
  - scene: calendar_event_approaching
    condition: minutes_before == 30
tools:
  - tool: calendar
    params: { event_id: "{{event.id}}" }
    required: true
  - tool: rss
    params: { query: "{{event.title}}", limit: 3 }
    required: false
  - tool: memory
    params: { scope: work_context }
    required: false
merge_policy: meeting_brief
output_to: [ podcast_generate, chat ]

---

# skills/smart_recommend.yaml
id: smart_recommend
name: 智能推荐
triggers:
  - scene: home_open
  - scene: idle
tools:
  - tool: memory
    params: { scope: preferences }
    required: true
  - tool: calendar
    params: { range: today }
    required: false
  - tool: weather
    params: { range: now }
    required: false
merge_policy: recommendation_score
output_to: [ recommend_list ]
```

---

## 六、逐次按需加载

### 6.1 含义

**逐次按需加载**：在「真正需要」的那一刻才去做「初始化 / 拉数」，而不是在应用启动时一次性加载所有工具与数据。

| 层次 | 按需的含义 | 示例 |
|------|------------|------|
| **工具** | 用到某工具时才初始化 | 用户从未触发日历相关场景时，不初始化日历 Adapter、不请求日历权限；第一次命中需要日历的 Skill 时，再加载。 |
| **Skill** | 只加载与当前场景相关的 Skill | 当前是「聊天」场景时，只解析 `triggers` 包含 chat 的 skill 文件。 |
| **数据** | 按本轮意图决定拉哪些、是否可短路 | Skill 列出 calendar / weather / email 均为 optional；可先拉日历，若已能构成足够上下文则不再拉天气/邮箱。 |

### 6.2 对本场景的价值

- **启动与内存**：工具越来越多时，不在启动时加载全部，冷启动更快、常驻内存更小。
- **权限与体验**：日历、邮箱等敏感权限在「第一次被真正用到」时再弹窗，更容易获得用户授权。
- **延迟与成本**：每次请求只拉本场景真正用到的工具和数据；可选工具可做成「能短路就短路」。
- **扩展性**：新工具接入后，即使用户从不使用，也不会增加启动成本和权限打扰。
- **故障隔离**：某工具超时或不可用时，其他工具不受影响；前一步失败可决定是否降级跳过。

### 6.3 设计要点

- **工具层**：维护「工具注册表」（轻量元数据）；具体工具的**系统 API 初始化**在首次被 Skill 引用时再执行；支持按工具维度的缓存/复用。
- **Skill 层**：Skill 配置按场景建索引或懒加载；`SkillsEngine` 根据当前 scene 只加载匹配的 Skill，再按 Skill 的 `tools` 列表逐项初始化工具并拉数。
- **数据拉取**：Skill 中可区分 `required` / optional；编排时可选策略：
  - 仅调用 required，optional 按需再拉；或
  - 按顺序调用，若某步已满足「足够上下文」则短路；或
  - 用户意图识别后只拉与意图直接相关的工具。

---

## 七、典型场景

### 7.1 场景一：推荐下生成播客

**场景**：用户从推荐入口发起「生成播客」时，用 Skills 决定拉取哪些信息源，合并后交给播客生成 pipeline，产出一期播客。

- **触发**：`scene: podcast_generate` 或 `podcast_generate_from_recommend`。
- **Skill 示例**：`recommend_to_podcast`，按需选择调用：
  - **RSS**：用户订阅的 RSS 源最新文章/摘要，作为「资讯/新闻」素材；
  - **邮箱**：未读摘要或高优先级邮件条数，作为「待办/关注」情境；
  - **日历**：今日或本周日程，作为「时间与节奏」情境；
  - **天气**：当日天气，作为开场或推荐时长/风格的参考。
- **组合方式**：各工具均为可选（`required: false`）；`merge_policy` 将多源结果合并为一份「情境 + 资讯」上下文。
- **透传**：合并后的上下文注入播客生成的 prompt，最终以**播客**（音频 + 标题/摘要）形式呈现。

### 7.2 场景二：聊天对话时使用 Skills

**场景**：用户在与应用聊天时，根据当前消息或识别出的意图，通过 Skills 选择调用日历、天气、邮箱、RSS 等工具，将结果融入回复。

- **触发**：`scene: chat`；结合意图识别（如「今天有什么会」「天气怎样」「我有多少未读邮件」）决定本轮要调用的工具。
- **Skill 示例**：`chat_context_tools`，按意图选择工具子集；先拉与意图最相关的工具，若已能回答则不再拉其余。
- **透传**：回复以**聊天**（文本或语音）形式呈现，用户无需感知背后调用了哪些工具。

聊天与播客共用同一套工具和 Skills 编排能力，只是出口形态不同。

---

## 八、可扩展性

### 8.1 新工具的接入

1. **实现 `AgentTool` 协议**：提供 id、name、description、execute 实现（系统 API 封装或 HTTP 调用）。
2. **在工具注册表中登记**：元数据即可；真实初始化遵循「逐次按需加载」，在首次被 Skill 引用时再执行。
3. **在 Skills 中按需引用**：在对应场景的 skill 配置里加入该 tool 及参数，无需改透传层逻辑。

### 8.2 新 Skill 的添加

- 新增配置文件，定义 `triggers`、`tools`、`merge_policy`、`output_to`。
- 若有新场景（如「睡前简报」），在 triggers 中增加对应 scene，`SkillsEngine` 识别后即可在该场景下按需组合工具。

### 8.3 平台差异（macOS / iOS）

- **Skills 层与透传层**：与平台无关，代码完全复用。
- **工具层**：底层实现随平台切换，但对 Skills 层暴露相同的 `AgentTool` 接口。

| 工具 | macOS | iOS |
|------|-------|-----|
| 苹果日历 | EventKit（In-App，永久） | EventKit（In-App，永久） |
| 天气 | Open-Meteo HTTP 直调 | Open-Meteo HTTP 直调 |
| 飞书日历 | 飞书 HTTP API 直调 | 飞书 HTTP API 直调 |
| 邮箱 | MailKit | MailKit |
| RSS | 现有 RSSService | 现有 RSSService |

> 未来如需接入社区 MCP Server（如 Notion、GitHub 等），只需新增一个 `MCPToolAdapter` 实现 `AgentTool` 协议，对 Skills 层完全透明。

---

## 九、与现有模块的关系

| 模块 | 关系说明 |
|------|----------|
| **Memory** | Memory 提供长期用户偏好与画像；Skills 决定「何时拉哪些工具」。生成/推荐时：Memory + 工具上下文（由 Skills 编排）一起注入 prompt。 |
| **用户行为追踪** | 行为事件可驱动场景识别（如「用户正在生成播客」），从而触发对应 Skills；工具使用情况也可作为行为事件回写，用于优化 Skill 策略。 |
| **播客生成 / 推荐** | 播客作为重工具，消费 Skills 编排后的情境上下文；同时播客自身能力（生成、推荐）也实现 `AgentTool` 协议，可被其他 Skill 调用。 |
| **聊天** | 聊天是透传层之一。Skills 编排的结果可注入聊天上下文；用户通过聊天与「组合后的能力」交互，无需感知背后调用了哪些工具。 |

---

## 十、透传形态：播客与聊天

- **播客**：长内容、语音、推荐列表等，由生成/推荐 pipeline 消费工具上下文后产出。
- **聊天**：短回复、问答、指令确认等，由聊天 pipeline 消费工具上下文或直接返回某工具结果（如「今天你有 3 个会议」）。

无论背后是单一工具还是多工具按需组合，对用户而言只有「听播客」和「聊天」两种入口与形态。

---

## 十一、实现优先级

### P0 — 基础骨架（必须先做）

| # | 任务 | 说明 |
|---|------|------|
| 1 | `AgentTool` 协议 + `SkillsEngine` | 定义工具接口，实现最小编排引擎（加载 Skill、匹配场景、调用工具、合并结果） |
| 2 | 将 `PodcastService` 包装为 `PodcastTool` | 现有代码不动，加一层 Adapter，验证整条链路 |
| 3 | `context_for_generation` Skill（仅 RSS） | 用现有 RSS 数据跑通「场景 → Skill → Tool → prompt」全流程 |

### P1 — 第一批真实工具

| # | 任务 | 说明 |
|---|------|------|
| 4 | `WeatherTool`（Open-Meteo） | In-App Adapter，CoreLocation 定位 + HTTP 调用，iOS/macOS 均可 |
| 5 | `AppleCalendarTool`（EventKit） | In-App Adapter，权限按需请求，iOS/macOS 均可 |
| 6 | 更新 `context_for_generation` Skill | 加入 weather + calendar，验证多工具按需组合与短路 |
| 7 | `morning_briefing` Skill | 验证定时触发场景 |

### P2 — 管理 UI

| # | 任务 | 说明 |
|---|------|------|
| 8 | 工具管理页 | 工具列表、状态、配置、测试（见第十二节） |
| 9 | Skills 管理页 | 技能列表、启用/禁用、编辑（见第十二节） |
| 10 | 权限管理（集成在工具管理页） | 在工具卡片中展示权限状态，提供跳转系统设置的入口（见 12.5 节） |

### P3 — 扩展工具与更多 Skills

| # | 任务 | 说明 |
|---|------|------|
| 10 | `FeishuCalendarTool` | In-App HTTP 调用飞书 API（App Token 认证） |
| 11 | `EmailTool`（MailKit） | In-App Adapter |
| 12 | 更多 Skills | meeting_prep、weekly_review、smart_recommend 等 |
| 13 | `MCPToolAdapter`（可选） | 按需接入社区 MCP Server，实现 `AgentTool` 协议包装远程调用 |

---

## 十二、可视化管理：工具与技能

### 12.1 导航入口

在侧边栏新增「工具与技能」导航项（图标：`wrench.and.screwdriver`），包含两个 Tab：**工具** 和 **技能（Skills）**。

### 12.2 工具管理页

```
┌─────────────────────────────────────────────────────────┐
│  工具                                        [+ 添加工具] │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌─────────────────────────────────────────────────┐    │
│  │  🟢 天气 (weather)                    In-App    │    │
│  │  当前及短期天气，支持自动定位                      │    │
│  │  权限：位置（已授权）          [测试] [配置]      │    │
│  └─────────────────────────────────────────────────┘    │
│                                                           │
│  ┌─────────────────────────────────────────────────┐    │
│  │  🟢 苹果日历 (calendar_apple)         In-App    │    │
│  │  读取 EventKit 日历事件                           │    │
│  │  权限：日历（已授权）          [测试] [配置]      │    │
│  └─────────────────────────────────────────────────┘    │
│                                                           │
│  ┌─────────────────────────────────────────────────┐    │
│  │  🟡 飞书日历 (calendar_feishu)       In-App    │    │
│  │  飞书开放平台日历 API                             │    │
│  │  需要配置 App ID / Secret      [测试] [配置]      │    │
│  └─────────────────────────────────────────────────┘    │
│                                                           │
│  ┌─────────────────────────────────────────────────┐    │
│  │  ⚫ 邮箱 (email)                      未启用    │    │
│  │  MailKit 未读摘要                                 │    │
│  │  权限：邮件（未授权）          [启用] [配置]      │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

**状态指示：**
- 🟢 已连接 / 已授权，可用
- 🟡 已配置但未完全就绪（缺少权限或配置项）
- ⚫ 未启用

**工具配置面板（点击「配置」展开）：**
- In-App Adapter：显示权限状态，提供「重新授权」按钮
- 第三方 HTTP（飞书等）：配置 App ID / Secret / Calendar ID

**测试功能：** 点击「测试」可发起一次真实调用，展示返回的原始数据，方便调试。

### 12.3 Skills 管理页

```
┌─────────────────────────────────────────────────────────┐
│  技能（Skills）                              [+ 新建技能] │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌─────────────────────────────────────────────────┐    │
│  │  ● 晨间简报          触发：定时 07:00-09:00      │    │
│  │    weather · calendar · rss · email              │    │
│  │    → 播客（5 min）                  [编辑] [▶]   │    │
│  └─────────────────────────────────────────────────┘    │
│                                                           │
│  ┌─────────────────────────────────────────────────┐    │
│  │  ● 生成时情境上下文   触发：podcast_generate     │    │
│  │    calendar · weather · email                    │    │
│  │    → prompt_context                [编辑] [▶]   │    │
│  └─────────────────────────────────────────────────┘    │
│                                                           │
│  ┌─────────────────────────────────────────────────┐    │
│  │  ○ 会议准备           触发：日历事件前 30 min    │    │
│  │    calendar · rss · memory                       │    │
│  │    → 播客 / 聊天（已禁用）         [编辑] [启用] │    │
│  └─────────────────────────────────────────────────┘    │
│                                                           │
│  ┌─────────────────────────────────────────────────┐    │
│  │  ● 智能推荐           触发：首页打开             │    │
│  │    memory · calendar · weather                   │    │
│  │    → 推荐列表                      [编辑] [▶]   │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

**Skill 编辑面板（点击「编辑」）：**
- 基本信息：名称、描述、启用开关
- 触发条件：场景选择 + 条件表达式
- 工具列表：拖拽排序，每个工具可设置 required/optional、默认参数
- 合并策略：下拉选择（concat_summary / structured_briefing / meeting_brief 等）
- 输出目标：多选（podcast_generate / chat / recommend_list）

**工具依赖可视化（Skill 详情内）：**
```
触发场景: podcast_generate
    │
    ├── [必须] calendar ──→ 今日事件
    ├── [可选] weather  ──→ 天气摘要
    └── [可选] email    ──→ 未读数
              │
              ▼
         merge_policy: concat_summary
              │
              ▼
         → prompt_context（注入生成 prompt）
```

### 12.4 实现建议

- 工具状态与配置存储在 `UserDefaults` / `Keychain`（敏感信息用 Keychain）
- Skills 配置以 JSON 文件存储在 App 沙盒 `skills/` 目录，支持导入/导出
- 管理页与现有 `SettingsView` 并列，作为独立导航项，不耦合设置逻辑
- 「测试」功能直接调用工具的 `execute()` 方法，结果展示在 Sheet 中

### 12.5 权限管理（集成在工具管理页）

权限状态作为工具卡片的一部分展示，不单独做页面。每个需要系统权限的工具在卡片中显示当前授权状态，并提供操作入口。

**权限状态展示：**

```
┌─────────────────────────────────────────────────────────┐
│  🟢 天气 (weather)                            In-App    │
│  当前及短期天气，支持自动定位                              │
│  📍 定位权限：已授权                  [测试] [配置]       │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  🟡 苹果日历 (calendar)                       In-App    │
│  读取 EventKit 日历事件                                   │
│  📅 日历权限：未授权  [前往系统设置]  [测试] [配置]       │
└─────────────────────────────────────────────────────────┘
```

**权限状态说明：**

| 状态 | 含义 | 操作 |
|------|------|------|
| 已授权 ✅ | 权限已获得，工具可正常使用 | 无需操作 |
| 未授权 ⚠️ | 用户尚未授权或已拒绝 | 显示「前往系统设置」按钮 |
| 不需要权限 | 工具不依赖系统权限（如 RSS） | 不显示权限行 |

**「前往系统设置」行为：**
- macOS：调用 `NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)`
- iOS：调用 `UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)`

**各工具对应的权限：**

| 工具 | 所需权限 | 系统设置路径 |
|------|---------|------------|
| `weather` | 定位服务 | 隐私与安全性 → 定位服务 |
| `calendar` | 日历 | 隐私与安全性 → 日历 |
| `email`（P3） | 邮件 | 隐私与安全性 → 邮件 |
| `rss`、`podcast` | 无 | — |

**实现要点：**
- 权限状态实时查询（每次进入工具管理页时刷新），不缓存
- 使用 `CLLocationManager.authorizationStatus` 和 `EKEventStore.authorizationStatus(for:)` 查询
- 权限变更后（用户从系统设置返回 App），自动刷新状态（监听 `UIApplication.didBecomeActiveNotification` / `NSApplication.didBecomeActiveNotification`）

---

## 文档变更与归属

- 本文档描述**工具（AgentTool 协议）**与 **Skills（编排策略）**在播客应用中的角色，以及可扩展工具架构。
- 与 [Memory功能设计方案.md](Memory功能设计方案.md)、[用户行为追踪与推荐系统设计.md](用户行为追踪与推荐系统设计.md) 等并列，共同构成应用的能力与数据架构设计。
