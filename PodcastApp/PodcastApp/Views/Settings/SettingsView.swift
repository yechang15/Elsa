import SwiftUI
import AVFoundation

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    @State private var testResult: String = ""
    @State private var isTesting: Bool = false
    @State private var ttsTestResult: String = ""
    @State private var isTestingTTS: Bool = false
    @State private var availableVoices: [AVSpeechSynthesisVoice] = []

    // 本地状态，避免焦点丢失
    @State private var localApiKey: String = ""
    @State private var localModel: String = ""
    @State private var isInitializing: Bool = true

    // 焦点管理
    @FocusState private var focusedField: Field?

    enum Field {
        case apiKey
        case model
    }

    var body: some View {
        Form {
            Section("LLM 配置") {
                Picker("API 提供商", selection: Binding(
                    get: { appState.userConfig.llmProvider },
                    set: { newValue in
                        // 使用 DispatchQueue 异步更新
                        DispatchQueue.main.async {
                            appState.userConfig.llmProvider = newValue
                            appState.saveConfig()
                        }
                    }
                )) {
                    Text("豆包").tag("豆包")
                    Text("OpenAI").tag("OpenAI")
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("API Key")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("输入 API Key", text: $localApiKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(height: 30)
                        .focused($focusedField, equals: .apiKey)
                        .onChange(of: localApiKey) { oldValue, newValue in
                            guard !isInitializing else { return }
                            DispatchQueue.main.async {
                                appState.userConfig.llmApiKey = newValue
                                appState.saveConfig()
                            }
                        }

                    Text("当前: \(appState.userConfig.llmApiKey.isEmpty ? "未设置" : "已设置 (\(appState.userConfig.llmApiKey.count) 字符)")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("模型")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("输入模型名称", text: $localModel)
                        .textFieldStyle(.roundedBorder)
                        .frame(height: 30)
                        .focused($focusedField, equals: .model)
                        .onChange(of: localModel) { oldValue, newValue in
                            guard !isInitializing else { return }
                            DispatchQueue.main.async {
                                appState.userConfig.llmModel = newValue
                                appState.saveConfig()
                            }
                        }

                    Text("当前: \(appState.userConfig.llmModel)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if appState.userConfig.llmProvider == "豆包" {
                    Text("豆包模型示例：doubao-seed-2-0-pro-260215")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // 测试连接按钮
                HStack {
                    Button(action: testConnection) {
                        HStack {
                            if isTesting {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                            Text(isTesting ? "测试中..." : "测试连接")
                        }
                    }
                    .disabled(appState.userConfig.llmApiKey.isEmpty || isTesting)

                    if !testResult.isEmpty {
                        Text(testResult)
                            .font(.caption)
                            .foregroundColor(testResult.contains("成功") ? .green : .red)
                    }
                }
            }
            
            Section("TTS 配置") {
                Picker("TTS 引擎", selection: asyncBinding(
                    get: { appState.userConfig.ttsEngine },
                    set: { appState.userConfig.ttsEngine = $0 }
                )) {
                    ForEach([TTSEngine.system, .openai, .elevenlabs], id: \.self) { engine in
                        Text(engine.rawValue).tag(engine)
                    }
                }

                if appState.userConfig.ttsEngine == .system {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("主播A语音")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Picker("", selection: asyncBinding(
                            get: { appState.userConfig.ttsVoiceA },
                            set: { appState.userConfig.ttsVoiceA = $0 }
                        )) {
                            ForEach(availableVoices, id: \.identifier) { voice in
                                Text(voice.name).tag(voice.identifier)
                            }
                        }
                        .labelsHidden()

                        Text("主播B语音")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Picker("", selection: asyncBinding(
                            get: { appState.userConfig.ttsVoiceB },
                            set: { appState.userConfig.ttsVoiceB = $0 }
                        )) {
                            ForEach(availableVoices, id: \.identifier) { voice in
                                Text(voice.name).tag(voice.identifier)
                            }
                        }
                        .labelsHidden()
                    }
                }

                Slider(value: asyncBinding(
                    get: { appState.userConfig.ttsSpeed },
                    set: { appState.userConfig.ttsSpeed = $0 }
                ), in: 0.5...2.0, step: 0.1) {
                    Text("语速: \(appState.userConfig.ttsSpeed, specifier: "%.1f")x")
                }

                // TTS 测试按钮
                HStack {
                    Button(action: testTTS) {
                        HStack {
                            if isTestingTTS {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                            Text(isTestingTTS ? "播放中..." : "测试语音")
                        }
                    }
                    .disabled(isTestingTTS)

                    if !ttsTestResult.isEmpty {
                        Text(ttsTestResult)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            Section("播客生成") {
                Picker("默认长度", selection: asyncBinding(
                    get: { appState.userConfig.defaultLength },
                    set: { appState.userConfig.defaultLength = $0 }
                )) {
                    Text("5分钟").tag(5)
                    Text("15分钟").tag(15)
                    Text("30分钟").tag(30)
                }

                Picker("内容深度", selection: asyncBinding(
                    get: { appState.userConfig.contentDepth },
                    set: { appState.userConfig.contentDepth = $0 }
                )) {
                    ForEach([ContentDepth.quick, .detailed], id: \.self) { depth in
                        Text(depth.rawValue).tag(depth)
                    }
                }

                Picker("主播风格", selection: asyncBinding(
                    get: { appState.userConfig.hostStyle },
                    set: { appState.userConfig.hostStyle = $0 }
                )) {
                    ForEach([HostStyle.casual, .serious, .humorous], id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }

                Toggle("自动生成", isOn: asyncBinding(
                    get: { appState.userConfig.autoGenerate },
                    set: { appState.userConfig.autoGenerate = $0 }
                ))
            }

            Section("通知") {
                Toggle("新播客生成时通知", isOn: asyncBinding(
                    get: { appState.userConfig.notifyNewPodcast },
                    set: { appState.userConfig.notifyNewPodcast = $0 }
                ))
                Toggle("RSS源更新时通知", isOn: asyncBinding(
                    get: { appState.userConfig.notifyRSSUpdate },
                    set: { appState.userConfig.notifyRSSUpdate = $0 }
                ))
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 600)
        .task {
            // 使用 .task 而不是 .onAppear
            // 初始化本地状态
            localApiKey = appState.userConfig.llmApiKey
            localModel = appState.userConfig.llmModel

            // 加载语音列表
            loadAvailableVoices()

            // 等待一小段时间后允许保存
            try? await Task.sleep(nanoseconds: 100_000_000)
            isInitializing = false
        }
    }

    // 加载可用语音
    private func loadAvailableVoices() {
        availableVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("zh") }

        DispatchQueue.main.async {
            // 如果当前配置的语音不在列表中，使用第一个
            if !self.availableVoices.contains(where: { $0.identifier == self.appState.userConfig.ttsVoiceA }),
               let firstVoice = self.availableVoices.first {
                self.appState.userConfig.ttsVoiceA = firstVoice.identifier
            }

            if !self.availableVoices.contains(where: { $0.identifier == self.appState.userConfig.ttsVoiceB }),
               let secondVoice = self.availableVoices.dropFirst().first ?? self.availableVoices.first {
                self.appState.userConfig.ttsVoiceB = secondVoice.identifier
            }

            self.appState.saveConfig()
        }
    }

    // 测试 TTS
    private func testTTS() {
        isTestingTTS = true
        ttsTestResult = ""

        Task {
            let ttsService = TTSService()
            let testText = "哈喽各位码友，今天咱们聊聊Swift的异步编程特性呀？"

            await MainActor.run {
                ttsService.speak(
                    text: testText,
                    voice: appState.userConfig.ttsVoiceA,
                    speed: Float(appState.userConfig.ttsSpeed)
                )
            }

            // 等待播放完成
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5秒

            await MainActor.run {
                ttsTestResult = "✅ 播放完成"
                isTestingTTS = false
            }
        }
    }

    // 测试连接
    private func testConnection() {
        isTesting = true
        testResult = ""

        Task {
            do {
                let provider: LLMProvider = appState.userConfig.llmProvider == "豆包" ? .doubao : .openai
                let llmService = LLMService(
                    apiKey: appState.userConfig.llmApiKey,
                    provider: provider,
                    model: appState.userConfig.llmModel
                )

                // 创建测试文章
                let testArticle = RSSArticle(
                    title: "测试文章",
                    link: "https://example.com",
                    description: "这是一个测试",
                    pubDate: Date(),
                    content: "测试内容"
                )

                let script = try await llmService.generatePodcastScript(
                    articles: [testArticle],
                    topics: ["测试"],
                    length: 1,
                    style: "轻松闲聊",
                    depth: "快速浏览"
                )

                await MainActor.run {
                    if script.isEmpty {
                        testResult = "❌ 连接失败：返回内容为空"
                    } else {
                        testResult = "✅ 连接成功！"
                    }
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testResult = "❌ 连接失败：\(error.localizedDescription)"
                    isTesting = false
                }
            }
        }
    }

    // 创建异步 Binding 的辅助函数，避免在视图更新期间修改 @Published
    private func asyncBinding<T>(
        get: @escaping () -> T,
        set: @escaping (T) -> Void
    ) -> Binding<T> {
        Binding(
            get: { get() },
            set: { newValue in
                DispatchQueue.main.async {
                    set(newValue)
                    appState.saveConfig()
                }
            }
        )
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
