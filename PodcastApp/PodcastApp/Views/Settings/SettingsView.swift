import SwiftUI
import AVFoundation

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    @State private var testResult: String = ""
    @State private var isTesting: Bool = false
    @State private var ttsTestResult: String = ""
    @State private var isTestingTTS: Bool = false
    @State private var availableVoices: [AVSpeechSynthesisVoice] = []

    var body: some View {
        Form {
            Section("LLM 配置") {
                Picker("API 提供商", selection: Binding(
                    get: { appState.userConfig.llmProvider },
                    set: { newValue in
                        appState.userConfig.llmProvider = newValue
                        appState.saveConfig()
                    }
                )) {
                    Text("豆包").tag("豆包")
                    Text("OpenAI").tag("OpenAI")
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("API Key")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("输入 API Key", text: Binding(
                        get: { appState.userConfig.llmApiKey },
                        set: { newValue in
                            print("🔵 TextField set 被调用: '\(newValue)'")
                            appState.userConfig.llmApiKey = newValue
                            appState.saveConfig()
                            print("🟢 保存后的值: '\(appState.userConfig.llmApiKey)'")
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(height: 30)
                    .onSubmit {
                        print("🟡 onSubmit 被调用")
                    }

                    HStack {
                        Text("当前: \(appState.userConfig.llmApiKey.isEmpty ? "未设置" : "已设置 (\(appState.userConfig.llmApiKey.count) 字符)")")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Button("显示值") {
                            print("📋 API Key 当前值: '\(appState.userConfig.llmApiKey)'")
                        }
                        .font(.caption2)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("模型")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("输入模型名称", text: Binding(
                        get: { appState.userConfig.llmModel },
                        set: { newValue in
                            appState.userConfig.llmModel = newValue
                            appState.saveConfig()
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(height: 30)

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
                Picker("TTS 引擎", selection: $appState.userConfig.ttsEngine) {
                    ForEach([TTSEngine.system, .openai, .elevenlabs], id: \.self) { engine in
                        Text(engine.rawValue).tag(engine)
                    }
                }

                if appState.userConfig.ttsEngine == .system {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("主播A语音")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Picker("", selection: $appState.userConfig.ttsVoiceA) {
                            ForEach(availableVoices, id: \.identifier) { voice in
                                Text(voice.name).tag(voice.identifier)
                            }
                        }
                        .labelsHidden()

                        Text("主播B语音")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Picker("", selection: $appState.userConfig.ttsVoiceB) {
                            ForEach(availableVoices, id: \.identifier) { voice in
                                Text(voice.name).tag(voice.identifier)
                            }
                        }
                        .labelsHidden()
                    }
                }

                Slider(value: $appState.userConfig.ttsSpeed, in: 0.5...2.0, step: 0.1) {
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
                Picker("默认长度", selection: $appState.userConfig.defaultLength) {
                    Text("5分钟").tag(5)
                    Text("15分钟").tag(15)
                    Text("30分钟").tag(30)
                }
                
                Picker("内容深度", selection: $appState.userConfig.contentDepth) {
                    ForEach([ContentDepth.quick, .detailed], id: \.self) { depth in
                        Text(depth.rawValue).tag(depth)
                    }
                }
                
                Picker("主播风格", selection: $appState.userConfig.hostStyle) {
                    ForEach([HostStyle.casual, .serious, .humorous], id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                
                Toggle("自动生成", isOn: $appState.userConfig.autoGenerate)
            }
         
            Section("通知") {
                Toggle("新播客生成时通知", isOn: $appState.userConfig.notifyNewPodcast)
                Toggle("RSS源更新时通知", isOn: $appState.userConfig.notifyRSSUpdate)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 600)
        .onAppear {
            loadAvailableVoices()
        }
    }

    // 加载可用语音
    private func loadAvailableVoices() {
        availableVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("zh") }

        // 如果当前配置的语音不在列表中，使用第一个
        if !availableVoices.contains(where: { $0.identifier == appState.userConfig.ttsVoiceA }),
           let firstVoice = availableVoices.first {
            appState.userConfig.ttsVoiceA = firstVoice.identifier
        }

        if !availableVoices.contains(where: { $0.identifier == appState.userConfig.ttsVoiceB }),
           let secondVoice = availableVoices.dropFirst().first ?? availableVoices.first {
            appState.userConfig.ttsVoiceB = secondVoice.identifier
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
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
