# 对话式播客应用 (Podcast App)

macOS 原生桌面应用，基于用户兴趣自动生成二人对话式播客。

## 技术栈

- **平台**: macOS 14.0+
- **语言**: Swift 5.9+
- **UI框架**: SwiftUI
- **数据持久化**: SwiftData
- **音频处理**: AVFoundation
- **依赖管理**: Swift Package Manager

## 项目结构

```
PodcastApp/
├── App/                    # 应用入口
├── Views/                  # 视图层
│   ├── Onboarding/        # 首次话题选择
│   ├── PodcastList/       # 播客列表
│   ├── Player/            # 播放界面
│   ├── Topics/            # 兴趣话题管理
│   ├── RSS/               # RSS订阅管理
│   ├── History/           # 收听历史
│   └── Settings/          # 设置界面
├── Models/                 # 数据模型
├── ViewModels/            # 视图模型
├── Services/              # 服务层
│   ├── RSS/              # RSS订阅服务
│   ├── LLM/              # LLM对话生成
│   ├── TTS/              # TTS语音合成
│   ├── Audio/            # 音频播放
│   └── Storage/          # 数据存储
├── Utils/                 # 工具类
└── Resources/             # 资源文件
```

## V0.1 功能

- ✅ 兴趣话题选择
- ✅ RSS订阅与管理
- ✅ 二人对话播客生成
- ✅ TTS语音合成
- ✅ 音频播放器
- ✅ 基础记忆（收听历史）

## 依赖库

- **FeedKit**: RSS解析
- **OpenAI Swift**: LLM API客户端
- **AVFoundation**: 音频播放和TTS（系统内置）

## 开发指南

### 环境要求

- macOS 14.0+
- Xcode 15.0+
- Swift 5.9+

### 构建项目

1. 打开 `PodcastApp.xcodeproj`
2. 选择目标设备为 "My Mac"
3. 点击 Run 或按 Cmd+R

### 配置

首次运行需要配置：
- OpenAI API Key（用于播客脚本生成）
- TTS引擎选择（系统TTS或OpenAI TTS）

## 架构说明

### MVVM架构

- **Models**: 数据模型（Topic, Podcast, RSSFeed等）
- **Views**: SwiftUI视图组件
- **ViewModels**: 业务逻辑和状态管理
- **Services**: 独立的服务模块（RSS、LLM、TTS、Audio）

### 数据流

```
User Input → ViewModel → Service → Model → ViewModel → View
```

### 状态管理

使用 SwiftUI 的 `@StateObject`, `@ObservedObject`, `@EnvironmentObject` 进行状态管理。

## 开发计划

### 第一阶段：基础架构 ✅
- 项目结构搭建
- 核心数据模型
- 基础服务层

### 第二阶段：UI实现
- 首次话题选择界面
- 播客列表界面
- 播放界面

### 第三阶段：功能集成
- RSS订阅功能
- LLM播客生成
- TTS语音合成
- 音频播放

### 第四阶段：完善与优化
- 收听历史
- 设置界面
- 错误处理
- 性能优化

## 许可证

待定
