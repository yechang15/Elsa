# Elsa

> 你的兴趣，AI 为你播报。

一款 macOS 原生 AI 个人助理，以个性化播客为核心交互形式。基于你的兴趣话题自动订阅 RSS 信息源，通过 LLM 生成二人对话式播客脚本，再经 TTS 合成语音播放。内置可扩展的 **Skills & Tools** 系统，支持调用日历、天气、邮件等三方工具，配合长期记忆持久化，让 AI 真正了解你、持续服务你。

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/swift-5.9%2B-orange)
![License](https://img.shields.io/badge/license-MIT-green)

---

## 功能特性

### 个人助理
- **Skills & Tools** — 可扩展的工具调用系统，内置日历、天气、邮件等工具；通过编写 Skill 规则，让 AI 在播客或对话中自动调用三方能力
- **长期记忆** — 持久化存储用户兴趣、收听习惯与偏好，AI 越用越懂你
- **行为追踪** — 分析收听行为，自动优化内容推荐权重
- **对话问答** — 内置 Chat 界面，可随时向 AI 提问，上下文感知记忆

### 个性化播客
- **兴趣话题管理** — 选择感兴趣的领域，系统自动映射到相关 RSS 源
- **RSS 订阅** — 自动拉取内容，支持手动添加/管理订阅源
- **AI 播客生成** — 基于 RSS 内容，LLM 生成自然的二人对话脚本
- **TTS 语音合成** — 支持火山引擎豆包 TTS、macOS 系统 TTS、OpenAI TTS、ElevenLabs
- **音频播放器** — 播放/暂停、进度控制、倍速播放
- **周期性自动生成** — 定时拉取内容并生成播客，无需手动触发

---

## 环境要求

- macOS 14.0+
- Xcode 15.0+
- 火山引擎豆包 API Key（LLM + TTS），或其他 OpenAI 兼容接口

---

## 快速开始

### 1. 克隆仓库并打开项目

```bash
git clone https://github.com/yechang15/myapp.git
cd myapp
open PodcastApp/PodcastApp.xcodeproj
```

### 2. 配置 API Key

首次运行后，在应用的「设置」界面配置：

**LLM（播客脚本生成 & 对话）**

- 支持豆包（Doubao）或任意 OpenAI 兼容接口
- 填入 API Key、Base URL 和模型名称
- 豆包模型示例：`doubao-seed-2-0-pro-260215`

**TTS（语音合成）**

- 推荐：火山引擎豆包 TTS（双向流式，音质最佳）
- 备选：macOS 系统 TTS（免费，无需配置）
- 其他：OpenAI TTS、ElevenLabs

### 3. 运行

在 Xcode 中选择 `My Mac` 目标，按 `Cmd+R` 运行。首次启动会进入话题选择界面，选择感兴趣的领域后即可开始使用。

---

## 文档

| 文档 | 说明 |
|------|------|
| [PRD](docs/PRD-对话式播客应用.md) | 产品需求与版本规划 |
| [架构设计](docs/ARCHITECTURE.md) | 项目架构与模块说明 |
| [Tools & Skills 设计](docs/MCP与Skills设计文档.md) | 工具系统设计文档 |
| [记忆系统设计](docs/Memory功能设计方案.md) | 记忆与个性化系统 |
| [行为追踪设计](docs/用户行为追踪与推荐系统设计.md) | 用户行为分析系统 |
| [UI 设计](docs/UI设计-对话式播客应用.md) | 界面设计规范 |

---

## 项目结构

```
├── PodcastApp/
│   └── PodcastApp/
│       ├── App/              # 应用入口与全局状态
│       ├── Models/           # SwiftData 数据模型
│       ├── Services/         # 业务逻辑层
│       │   ├── LLM/          # LLM 服务（豆包/OpenAI 兼容）
│       │   ├── TTS/          # TTS 语音合成（火山引擎双向流式）
│       │   ├── RSS/          # RSS 订阅与解析
│       │   ├── Audio/        # 音频播放
│       │   └── Tools/        # Skills & Tools 系统
│       ├── Views/            # SwiftUI 视图
│       └── ViewModels/       # 视图模型
├── docs/                     # 设计文档
├── README.md
└── LICENSE
```

---

## 技术栈

| 层 | 技术 |
|----|------|
| UI | SwiftUI |
| 数据持久化 | SwiftData |
| 音频 | AVFoundation |
| LLM | 豆包（Doubao）/ OpenAI 兼容接口 |
| TTS | 火山引擎豆包 TTS（双向流式 WebSocket） |

---

## 贡献

欢迎提交 Issue 和 Pull Request。

项目预留了以下扩展点，适合社区贡献：

- 新的数据源适配器（RSS 之外的内容源）
- 新的 TTS 引擎接入（实现 `TTSEngine` 协议）
- 新的 AgentTool 工具（实现 `AgentTool` 协议）
- 播客生成策略优化（Prompt 工程）

---

## License

[MIT](LICENSE)
