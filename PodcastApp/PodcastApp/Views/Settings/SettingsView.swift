import SwiftUI
import AVFoundation

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    @State private var testResult: String = ""
    @State private var isTesting: Bool = false
    @State private var ttsTestResultA: String = ""
    @State private var isTestingTTSA: Bool = false
    @State private var ttsTestResultB: String = ""
    @State private var isTestingTTSB: Bool = false
    @State private var availableVoices: [AVSpeechSynthesisVoice] = []

    // 本地状态，避免焦点丢失
    @State private var localApiKey: String = ""
    @State private var localModel: String = ""
    @State private var localTestTextA: String = ""
    @State private var localTestTextB: String = ""
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
                VStack(alignment: .leading, spacing: 8) {
                    Picker("TTS 引擎", selection: asyncBinding(
                        get: { appState.userConfig.ttsEngine },
                        set: { appState.userConfig.ttsEngine = $0 }
                    )) {
                        ForEach([TTSEngine.system, .openai, .elevenlabs, .doubaoPodcast], id: \.self) { engine in
                            Text(engine.rawValue).tag(engine)
                        }
                    }

                    // 引擎说明
                    Group {
                        switch appState.userConfig.ttsEngine {
                        case .system:
                            VStack(alignment: .leading, spacing: 4) {
                                Text("📱 纯TTS引擎")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                                Text("• 使用 macOS 系统自带的语音合成")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("• 需要配合上方的 LLM 先生成对话脚本")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("• 流程：原文 → LLM生成脚本 → 系统TTS转语音")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        case .openai:
                            VStack(alignment: .leading, spacing: 4) {
                                Text("📱 纯TTS引擎")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                                Text("• 使用 OpenAI 的高质量语音合成")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("• 需要配合上方的 LLM 先生成对话脚本")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("• 流程：原文 → LLM生成脚本 → OpenAI TTS转语音")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        case .elevenlabs:
                            VStack(alignment: .leading, spacing: 4) {
                                Text("📱 纯TTS引擎")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                                Text("• 使用 ElevenLabs 的超自然语音合成")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("• 需要配合上方的 LLM 先生成对话脚本")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("• 流程：原文 → LLM生成脚本 → ElevenLabs转语音")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        case .doubaoPodcast:
                            VStack(alignment: .leading, spacing: 4) {
                                Text("🎙️ 一体化播客引擎")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                                Text("• 豆包播客API自动完成脚本生成和语音合成")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("• 不需要单独配置 LLM，一步到位")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("• 流程：原文 → 豆包播客API → 播客音频（一步完成）")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }

                if appState.userConfig.ttsEngine == .system {
                    // 主播A配置
                    GroupBox(label: Text("主播A配置").font(.headline)) {
                        VStack(alignment: .leading, spacing: 12) {
                            // 语音选择
                            VStack(alignment: .leading, spacing: 4) {
                                Text("语音")
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
                            }

                            // 语速控制
                            VStack(alignment: .leading, spacing: 4) {
                                Text("语速: \(appState.userConfig.ttsSpeedA, specifier: "%.1f")x")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Slider(value: asyncBinding(
                                    get: { appState.userConfig.ttsSpeedA },
                                    set: { appState.userConfig.ttsSpeedA = $0 }
                                ), in: 0.5...2.0, step: 0.1)
                            }

                            // 测试文案
                            VStack(alignment: .leading, spacing: 4) {
                                Text("测试文案")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextEditor(text: $localTestTextA)
                                    .frame(height: 60)
                                    .font(.body)
                                    .border(Color.gray.opacity(0.3), width: 1)
                                    .cornerRadius(4)
                                    .onChange(of: localTestTextA) { oldValue, newValue in
                                        guard !isInitializing else { return }
                                        DispatchQueue.main.async {
                                            appState.userConfig.ttsTestTextA = newValue
                                            appState.saveConfig()
                                        }
                                    }
                            }

                            // 测试按钮
                            HStack {
                                Button(action: { testTTS(voice: appState.userConfig.ttsVoiceA, speed: appState.userConfig.ttsSpeedA, text: appState.userConfig.ttsTestTextA, isHostA: true) }) {
                                    HStack {
                                        if isTestingTTSA {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                        }
                                        Text(isTestingTTSA ? "播放中..." : "测试主播A")
                                    }
                                }
                                .disabled(isTestingTTSA)

                                if !ttsTestResultA.isEmpty {
                                    Text(ttsTestResultA)
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    // 主播B配置
                    GroupBox(label: Text("主播B配置").font(.headline)) {
                        VStack(alignment: .leading, spacing: 12) {
                            // 语音选择
                            VStack(alignment: .leading, spacing: 4) {
                                Text("语音")
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

                            // 语速控制
                            VStack(alignment: .leading, spacing: 4) {
                                Text("语速: \(appState.userConfig.ttsSpeedB, specifier: "%.1f")x")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Slider(value: asyncBinding(
                                    get: { appState.userConfig.ttsSpeedB },
                                    set: { appState.userConfig.ttsSpeedB = $0 }
                                ), in: 0.5...2.0, step: 0.1)
                            }

                            // 测试文案
                            VStack(alignment: .leading, spacing: 4) {
                                Text("测试文案")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextEditor(text: $localTestTextB)
                                    .frame(height: 60)
                                    .font(.body)
                                    .border(Color.gray.opacity(0.3), width: 1)
                                    .cornerRadius(4)
                                    .onChange(of: localTestTextB) { oldValue, newValue in
                                        guard !isInitializing else { return }
                                        DispatchQueue.main.async {
                                            appState.userConfig.ttsTestTextB = newValue
                                            appState.saveConfig()
                                        }
                                    }
                            }

                            // 测试按钮
                            HStack {
                                Button(action: { testTTS(voice: appState.userConfig.ttsVoiceB, speed: appState.userConfig.ttsSpeedB, text: appState.userConfig.ttsTestTextB, isHostA: false) }) {
                                    HStack {
                                        if isTestingTTSB {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                        }
                                        Text(isTestingTTSB ? "播放中..." : "测试主播B")
                                    }
                                }
                                .disabled(isTestingTTSB)

                                if !ttsTestResultB.isEmpty {
                                    Text(ttsTestResultB)
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                // OpenAI TTS 配置
                if appState.userConfig.ttsEngine == .openai {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("OpenAI TTS 配置")
                            .font(.headline)

                        TextField("API Key", text: asyncBinding(
                            get: { appState.userConfig.openaiTTSApiKey },
                            set: { appState.userConfig.openaiTTSApiKey = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)

                        Picker("模型", selection: asyncBinding(
                            get: { appState.userConfig.openaiTTSModel },
                            set: { appState.userConfig.openaiTTSModel = $0 }
                        )) {
                            Text("tts-1 (标准)").tag("tts-1")
                            Text("tts-1-hd (高清)").tag("tts-1-hd")
                        }

                        HStack(spacing: 20) {
                            VStack(alignment: .leading) {
                                Text("主播A语音")
                                    .font(.caption)
                                Picker("", selection: asyncBinding(
                                    get: { appState.userConfig.openaiTTSVoiceA },
                                    set: { appState.userConfig.openaiTTSVoiceA = $0 }
                                )) {
                                    Text("Alloy").tag("alloy")
                                    Text("Echo").tag("echo")
                                    Text("Fable").tag("fable")
                                    Text("Onyx").tag("onyx")
                                    Text("Nova").tag("nova")
                                    Text("Shimmer").tag("shimmer")
                                }
                                .labelsHidden()
                            }

                            VStack(alignment: .leading) {
                                Text("主播B语音")
                                    .font(.caption)
                                Picker("", selection: asyncBinding(
                                    get: { appState.userConfig.openaiTTSVoiceB },
                                    set: { appState.userConfig.openaiTTSVoiceB = $0 }
                                )) {
                                    Text("Alloy").tag("alloy")
                                    Text("Echo").tag("echo")
                                    Text("Fable").tag("fable")
                                    Text("Onyx").tag("onyx")
                                    Text("Nova").tag("nova")
                                    Text("Shimmer").tag("shimmer")
                                }
                                .labelsHidden()
                            }
                        }

                        Text("⚠️ OpenAI TTS 功能尚未实现，敬请期待")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.vertical, 8)
                }

                // ElevenLabs TTS 配置
                if appState.userConfig.ttsEngine == .elevenlabs {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ElevenLabs TTS 配置")
                            .font(.headline)

                        TextField("API Key", text: asyncBinding(
                            get: { appState.userConfig.elevenlabsApiKey },
                            set: { appState.userConfig.elevenlabsApiKey = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)

                        TextField("主播A Voice ID", text: asyncBinding(
                            get: { appState.userConfig.elevenlabsVoiceA },
                            set: { appState.userConfig.elevenlabsVoiceA = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)

                        TextField("主播B Voice ID", text: asyncBinding(
                            get: { appState.userConfig.elevenlabsVoiceB },
                            set: { appState.userConfig.elevenlabsVoiceB = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)

                        Text("⚠️ ElevenLabs TTS 功能尚未实现，敬请期待")
                            .font(.caption)
                            .foregroundColor(.orange)

                        Text("提示：Voice ID 可以在 ElevenLabs 控制台中找到")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                // 豆包播客API配置
                if appState.userConfig.ttsEngine == .doubaoPodcast {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("豆包播客API配置")
                            .font(.headline)

                        TextField("API Key", text: asyncBinding(
                            get: { appState.userConfig.doubaoPodcastApiKey },
                            set: { appState.userConfig.doubaoPodcastApiKey = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)

                        HStack(spacing: 20) {
                            VStack(alignment: .leading) {
                                Text("主播A语音ID")
                                    .font(.caption)
                                TextField("", text: asyncBinding(
                                    get: { appState.userConfig.doubaoPodcastVoiceA },
                                    set: { appState.userConfig.doubaoPodcastVoiceA = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                            }

                            VStack(alignment: .leading) {
                                Text("主播B语音ID")
                                    .font(.caption)
                                TextField("", text: asyncBinding(
                                    get: { appState.userConfig.doubaoPodcastVoiceB },
                                    set: { appState.userConfig.doubaoPodcastVoiceB = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                            }
                        }

                        Text("⚠️ 豆包播客API功能尚未实现，敬请期待")
                            .font(.caption)
                            .foregroundColor(.orange)

                        Text("提示：使用此模式时，将直接调用豆包播客API，不使用上方的LLM配置")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
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
            localTestTextA = appState.userConfig.ttsTestTextA
            localTestTextB = appState.userConfig.ttsTestTextB

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
    private func testTTS(voice: String, speed: Double, text: String, isHostA: Bool) {
        if isHostA {
            isTestingTTSA = true
            ttsTestResultA = ""
        } else {
            isTestingTTSB = true
            ttsTestResultB = ""
        }

        Task {
            let ttsService = TTSService()

            await MainActor.run {
                ttsService.speak(
                    text: text,
                    voice: voice,
                    speed: Float(speed)
                )
            }

            // 等待播放完成
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5秒

            await MainActor.run {
                if isHostA {
                    ttsTestResultA = "✅ 播放完成"
                    isTestingTTSA = false
                } else {
                    ttsTestResultB = "✅ 播放完成"
                    isTestingTTSB = false
                }
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
                    self.appState.saveConfig()
                }
            }
        )
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
