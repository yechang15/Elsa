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
    @State private var isTestingDoubaoPodcast: Bool = false
    @State private var doubaoPodcastTestResult: String = ""
    @State private var doubaoPodcastTestProgress: String = ""

    // 本地状态，避免焦点丢失和并发问题
    @State private var localApiKey: String = ""
    @State private var localModel: String = ""
    @State private var localTestTextA: String = ""
    @State private var localTestTextB: String = ""
    @State private var localLLMProvider: String = ""
    @State private var localTTSEngine: TTSEngine = .system
    @State private var localTTSVoiceA: String = ""
    @State private var localTTSVoiceB: String = ""
    @State private var localTTSSpeedA: Double = 1.0
    @State private var localTTSSpeedB: Double = 1.0

    // OpenAI TTS 配置
    @State private var localOpenAITTSApiKey: String = ""
    @State private var localOpenAITTSModel: String = ""
    @State private var localOpenAITTSVoiceA: String = ""
    @State private var localOpenAITTSVoiceB: String = ""

    // ElevenLabs 配置
    @State private var localElevenLabsApiKey: String = ""
    @State private var localElevenLabsVoiceA: String = ""
    @State private var localElevenLabsVoiceB: String = ""

    // 豆包播客配置
    @State private var localDoubaoPodcastAppId: String = ""
    @State private var localDoubaoPodcastAccessToken: String = ""
    @State private var localDoubaoPodcastVoiceA: String = ""
    @State private var localDoubaoPodcastVoiceB: String = ""

    // 播客生成配置
    @State private var localDefaultLength: Int = 15
    @State private var localContentDepth: ContentDepth = .quick
    @State private var localHostStyle: HostStyle = .casual
    @State private var localAutoGenerate: Bool = true

    // 通知配置
    @State private var localNotifyNewPodcast: Bool = true
    @State private var localNotifyRSSUpdate: Bool = true

    @State private var isInitializing: Bool = true
    @State private var isLoaded: Bool = false

    // 焦点管理
    @FocusState private var focusedField: Field?

    enum Field {
        case apiKey
        case model
    }

    var body: some View {
        Group {
            if isLoaded {
                settingsForm
            } else {
                ProgressView("加载设置...")
                    .frame(width: 500, height: 600)
            }
        }
        .task {
            // 先标记为初始化中，阻止所有更新
            isInitializing = true

            // 延迟一下，确保视图完全加载
            try? await Task.sleep(nanoseconds: 100_000_000)

            // 初始化所有本地状态（从 appState 读取）
            await MainActor.run {
                localApiKey = appState.userConfig.llmApiKey
                localModel = appState.userConfig.llmModel
                localTestTextA = appState.userConfig.ttsTestTextA
                localTestTextB = appState.userConfig.ttsTestTextB
                localLLMProvider = appState.userConfig.llmProvider
                localTTSEngine = appState.userConfig.ttsEngine
                localTTSVoiceA = appState.userConfig.ttsVoiceA
                localTTSVoiceB = appState.userConfig.ttsVoiceB
                localTTSSpeedA = appState.userConfig.ttsSpeedA
                localTTSSpeedB = appState.userConfig.ttsSpeedB

                localOpenAITTSApiKey = appState.userConfig.openaiTTSApiKey
                localOpenAITTSModel = appState.userConfig.openaiTTSModel
                localOpenAITTSVoiceA = appState.userConfig.openaiTTSVoiceA
                localOpenAITTSVoiceB = appState.userConfig.openaiTTSVoiceB

                localElevenLabsApiKey = appState.userConfig.elevenlabsApiKey
                localElevenLabsVoiceA = appState.userConfig.elevenlabsVoiceA
                localElevenLabsVoiceB = appState.userConfig.elevenlabsVoiceB

                localDoubaoPodcastAppId = appState.userConfig.doubaoPodcastAppId
                localDoubaoPodcastAccessToken = appState.userConfig.doubaoPodcastAccessToken
                localDoubaoPodcastVoiceA = appState.userConfig.doubaoPodcastVoiceA
                localDoubaoPodcastVoiceB = appState.userConfig.doubaoPodcastVoiceB

                localDefaultLength = appState.userConfig.defaultLength
                localContentDepth = appState.userConfig.contentDepth
                localHostStyle = appState.userConfig.hostStyle
                localAutoGenerate = appState.userConfig.autoGenerate

                localNotifyNewPodcast = appState.userConfig.notifyNewPodcast
                localNotifyRSSUpdate = appState.userConfig.notifyRSSUpdate

                // 加载语音列表
                loadAvailableVoices()
            }

            // 再等待一下
            try? await Task.sleep(nanoseconds: 100_000_000)

            // 标记为已加载，触发视图渲染
            await MainActor.run {
                isLoaded = true
            }

            // 等待更长时间后才允许保存
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                isInitializing = false
            }
        }
    }

    private var settingsForm: some View {
        Form {
            Section("LLM 配置") {
                Picker("API 提供商", selection: $localLLMProvider) {
                    Text("豆包").tag("豆包")
                    Text("OpenAI").tag("OpenAI")
                }
                .onChange(of: localLLMProvider) { oldValue, newValue in
                    guard !isInitializing else { return }
                    Task { @MainActor in
                        appState.userConfig.llmProvider = newValue
                        appState.saveConfig()
                    }
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
                            Task { @MainActor in
                                appState.userConfig.llmApiKey = newValue
                                appState.saveConfig()
                            }
                        }

                    Text("当前: \(localApiKey.isEmpty ? "未设置" : "已设置 (\(localApiKey.count) 字符)")")
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
                            Task { @MainActor in
                                appState.userConfig.llmModel = newValue
                                appState.saveConfig()
                            }
                        }

                    Text("当前: \(localModel)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if localLLMProvider == "豆包" {
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
                    .disabled(localApiKey.isEmpty || isTesting)

                    if !testResult.isEmpty {
                        Text(testResult)
                            .font(.caption)
                            .foregroundColor(testResult.contains("成功") ? .green : .red)
                    }
                }
            }
            
            Section("TTS 配置") {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("TTS 引擎", selection: $localTTSEngine) {
                        ForEach([TTSEngine.system, .openai, .elevenlabs, .doubaoPodcast], id: \.self) { engine in
                            Text(engine.rawValue).tag(engine)
                        }
                    }
                    .onChange(of: localTTSEngine) { oldValue, newValue in
                        guard !isInitializing else { return }
                        Task { @MainActor in
                            appState.userConfig.ttsEngine = newValue
                            appState.saveConfig()
                        }
                    }

                    // 引擎说明
                    Group {
                        switch localTTSEngine {
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

                if localTTSEngine == .system {
                    // 主播A配置
                    GroupBox(label: Text("主播A配置").font(.headline)) {
                        VStack(alignment: .leading, spacing: 12) {
                            // 语音选择
                            VStack(alignment: .leading, spacing: 4) {
                                Text("语音")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Picker("", selection: $localTTSVoiceA) {
                                    ForEach(availableVoices, id: \.identifier) { voice in
                                        Text(voice.name).tag(voice.identifier)
                                    }
                                }
                                .labelsHidden()
                                .onChange(of: localTTSVoiceA) { oldValue, newValue in
                                    guard !isInitializing else { return }
                                    Task { @MainActor in
                                        appState.userConfig.ttsVoiceA = newValue
                                        appState.saveConfig()
                                    }
                                }
                            }

                            // 语速控制
                            VStack(alignment: .leading, spacing: 4) {
                                Text("语速: \(localTTSSpeedA, specifier: "%.1f")x")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Slider(value: $localTTSSpeedA, in: 0.5...2.0, step: 0.1)
                                    .onChange(of: localTTSSpeedA) { oldValue, newValue in
                                        guard !isInitializing else { return }
                                        Task { @MainActor in
                                            appState.userConfig.ttsSpeedA = newValue
                                            appState.saveConfig()
                                        }
                                    }
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
                                        Task { @MainActor in
                                            appState.userConfig.ttsTestTextA = newValue
                                            appState.saveConfig()
                                        }
                                    }
                            }

                            // 测试按钮
                            HStack {
                                Button(action: { testTTS(voice: localTTSVoiceA, speed: localTTSSpeedA, text: localTestTextA, isHostA: true) }) {
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
                                Picker("", selection: $localTTSVoiceB) {
                                    ForEach(availableVoices, id: \.identifier) { voice in
                                        Text(voice.name).tag(voice.identifier)
                                    }
                                }
                                .labelsHidden()
                                .onChange(of: localTTSVoiceB) { oldValue, newValue in
                                    guard !isInitializing else { return }
                                    Task { @MainActor in
                                        appState.userConfig.ttsVoiceB = newValue
                                        appState.saveConfig()
                                    }
                                }
                            }

                            // 语速控制
                            VStack(alignment: .leading, spacing: 4) {
                                Text("语速: \(localTTSSpeedB, specifier: "%.1f")x")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Slider(value: $localTTSSpeedB, in: 0.5...2.0, step: 0.1)
                                    .onChange(of: localTTSSpeedB) { oldValue, newValue in
                                        guard !isInitializing else { return }
                                        Task { @MainActor in
                                            appState.userConfig.ttsSpeedB = newValue
                                            appState.saveConfig()
                                        }
                                    }
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
                                        Task { @MainActor in
                                            appState.userConfig.ttsTestTextB = newValue
                                            appState.saveConfig()
                                        }
                                    }
                            }

                            // 测试按钮
                            HStack {
                                Button(action: { testTTS(voice: localTTSVoiceB, speed: localTTSSpeedB, text: localTestTextB, isHostA: false) }) {
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
                if localTTSEngine == .openai {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("OpenAI TTS 配置")
                            .font(.headline)

                        TextField("API Key", text: $localOpenAITTSApiKey)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: localOpenAITTSApiKey) { oldValue, newValue in
                            guard !isInitializing else { return }
                            Task { @MainActor in
                                appState.userConfig.openaiTTSApiKey = newValue
                                appState.saveConfig()
                            }
                        }

                        Picker("模型", selection: $localOpenAITTSModel) {
                            Text("tts-1 (标准)").tag("tts-1")
                            Text("tts-1-hd (高清)").tag("tts-1-hd")
                        }
                        .onChange(of: localOpenAITTSModel) { oldValue, newValue in
                            guard !isInitializing else { return }
                            Task { @MainActor in
                                appState.userConfig.openaiTTSModel = newValue
                                appState.saveConfig()
                            }
                        }

                        HStack(spacing: 20) {
                            VStack(alignment: .leading) {
                                Text("主播A语音")
                                    .font(.caption)
                                Picker("", selection: $localOpenAITTSVoiceA) {
                                    Text("Alloy").tag("alloy")
                                    Text("Echo").tag("echo")
                                    Text("Fable").tag("fable")
                                    Text("Onyx").tag("onyx")
                                    Text("Nova").tag("nova")
                                    Text("Shimmer").tag("shimmer")
                                }
                                .labelsHidden()
                                .onChange(of: localOpenAITTSVoiceA) { oldValue, newValue in
                                    guard !isInitializing else { return }
                                    Task { @MainActor in
                                        appState.userConfig.openaiTTSVoiceA = newValue
                                        appState.saveConfig()
                                    }
                                }
                            }

                            VStack(alignment: .leading) {
                                Text("主播B语音")
                                    .font(.caption)
                                Picker("", selection: $localOpenAITTSVoiceB) {
                                    Text("Alloy").tag("alloy")
                                    Text("Echo").tag("echo")
                                    Text("Fable").tag("fable")
                                    Text("Onyx").tag("onyx")
                                    Text("Nova").tag("nova")
                                    Text("Shimmer").tag("shimmer")
                                }
                                .labelsHidden()
                                .onChange(of: localOpenAITTSVoiceB) { oldValue, newValue in
                                    guard !isInitializing else { return }
                                    Task { @MainActor in
                                        appState.userConfig.openaiTTSVoiceB = newValue
                                        appState.saveConfig()
                                    }
                                }
                            }
                        }

                        Text("⚠️ OpenAI TTS 功能尚未实现，敬请期待")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.vertical, 8)
                }

                // ElevenLabs TTS 配置
                if localTTSEngine == .elevenlabs {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ElevenLabs TTS 配置")
                            .font(.headline)

                        TextField("API Key", text: $localElevenLabsApiKey)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: localElevenLabsApiKey) { oldValue, newValue in
                            guard !isInitializing else { return }
                            Task { @MainActor in
                                appState.userConfig.elevenlabsApiKey = newValue
                                appState.saveConfig()
                            }
                        }

                        TextField("主播A Voice ID", text: $localElevenLabsVoiceA)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: localElevenLabsVoiceA) { oldValue, newValue in
                            guard !isInitializing else { return }
                            Task { @MainActor in
                                appState.userConfig.elevenlabsVoiceA = newValue
                                appState.saveConfig()
                            }
                        }

                        TextField("主播B Voice ID", text: $localElevenLabsVoiceB)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: localElevenLabsVoiceB) { oldValue, newValue in
                            guard !isInitializing else { return }
                            Task { @MainActor in
                                appState.userConfig.elevenlabsVoiceB = newValue
                                appState.saveConfig()
                            }
                        }

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
                if localTTSEngine == .doubaoPodcast {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("豆包播客API配置")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("APP ID")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("输入 APP ID", text: $localDoubaoPodcastAppId)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: localDoubaoPodcastAppId) { oldValue, newValue in
                                guard !isInitializing else { return }
                                Task { @MainActor in
                                    appState.userConfig.doubaoPodcastAppId = newValue
                                    appState.saveConfig()
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Access Token")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("输入 Access Token", text: $localDoubaoPodcastAccessToken)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: localDoubaoPodcastAccessToken) { oldValue, newValue in
                                guard !isInitializing else { return }
                                Task { @MainActor in
                                    appState.userConfig.doubaoPodcastAccessToken = newValue
                                    appState.saveConfig()
                                }
                            }
                        }

                        HStack(spacing: 20) {
                            VStack(alignment: .leading) {
                                Text("主播A语音ID")
                                    .font(.caption)
                                TextField("", text: $localDoubaoPodcastVoiceA)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: localDoubaoPodcastVoiceA) { oldValue, newValue in
                                    guard !isInitializing else { return }
                                    Task { @MainActor in
                                        appState.userConfig.doubaoPodcastVoiceA = newValue
                                        appState.saveConfig()
                                    }
                                }
                            }

                            VStack(alignment: .leading) {
                                Text("主播B语音ID")
                                    .font(.caption)
                                TextField("", text: $localDoubaoPodcastVoiceB)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: localDoubaoPodcastVoiceB) { oldValue, newValue in
                                    guard !isInitializing else { return }
                                    Task { @MainActor in
                                        appState.userConfig.doubaoPodcastVoiceB = newValue
                                        appState.saveConfig()
                                    }
                                }
                            }
                        }

                        Text("使用此模式时，将直接调用豆包播客API，不使用上方的LLM配置")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        // 测试按钮
                        VStack(alignment: .leading, spacing: 8) {
                            Button(action: testDoubaoPodcast) {
                                HStack {
                                    if isTestingDoubaoPodcast {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    }
                                    Text(isTestingDoubaoPodcast ? "生成中..." : "测试生成播客")
                                }
                            }
                            .disabled(isTestingDoubaoPodcast || appState.userConfig.doubaoPodcastAppId.isEmpty || appState.userConfig.doubaoPodcastAccessToken.isEmpty)

                            if !doubaoPodcastTestProgress.isEmpty {
                                Text(doubaoPodcastTestProgress)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }

                            if !doubaoPodcastTestResult.isEmpty {
                                Text(doubaoPodcastTestResult)
                                    .font(.caption)
                                    .foregroundColor(doubaoPodcastTestResult.hasPrefix("✅") ? .green : .red)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            Section("播客生成") {
                Picker("默认长度", selection: $localDefaultLength) {
                    Text("5分钟").tag(5)
                    Text("15分钟").tag(15)
                    Text("30分钟").tag(30)
                }
                .onChange(of: localDefaultLength) { oldValue, newValue in
                    guard !isInitializing else { return }
                    Task { @MainActor in
                        appState.userConfig.defaultLength = newValue
                        appState.saveConfig()
                    }
                }

                Picker("内容深度", selection: $localContentDepth) {
                    ForEach([ContentDepth.quick, .detailed], id: \.self) { depth in
                        Text(depth.rawValue).tag(depth)
                    }
                }
                .onChange(of: localContentDepth) { oldValue, newValue in
                    guard !isInitializing else { return }
                    Task { @MainActor in
                        appState.userConfig.contentDepth = newValue
                        appState.saveConfig()
                    }
                }

                Picker("主播风格", selection: $localHostStyle) {
                    ForEach([HostStyle.casual, .serious, .humorous], id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .onChange(of: localHostStyle) { oldValue, newValue in
                    guard !isInitializing else { return }
                    Task { @MainActor in
                        appState.userConfig.hostStyle = newValue
                        appState.saveConfig()
                    }
                }

                Toggle("自动生成", isOn: $localAutoGenerate)
                    .onChange(of: localAutoGenerate) { oldValue, newValue in
                        guard !isInitializing else { return }
                        Task { @MainActor in
                            appState.userConfig.autoGenerate = newValue
                            appState.saveConfig()
                        }
                    }
            }

            Section("通知") {
                Toggle("新播客生成时通知", isOn: $localNotifyNewPodcast)
                    .onChange(of: localNotifyNewPodcast) { oldValue, newValue in
                        guard !isInitializing else { return }
                        Task { @MainActor in
                            appState.userConfig.notifyNewPodcast = newValue
                            appState.saveConfig()
                        }
                    }
                Toggle("RSS源更新时通知", isOn: $localNotifyRSSUpdate)
                    .onChange(of: localNotifyRSSUpdate) { oldValue, newValue in
                        guard !isInitializing else { return }
                        Task { @MainActor in
                            appState.userConfig.notifyRSSUpdate = newValue
                            appState.saveConfig()
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 600)
    }

    // 加载可用语音
    private func loadAvailableVoices() {
        availableVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("zh") }

        // 不要在初始化时自动修改配置，避免并发问题
        // 只在用户主动选择时才保存
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

    // 测试豆包播客API
    private func testDoubaoPodcast() {
        isTestingDoubaoPodcast = true
        doubaoPodcastTestResult = ""
        doubaoPodcastTestProgress = ""

        Task {
            do {
                let appId = appState.userConfig.doubaoPodcastAppId
                let accessToken = appState.userConfig.doubaoPodcastAccessToken

                // 创建测试输入
                let testInput = """
                # 播客主题
                测试主题

                # 内容要求
                - 时长: 1分钟
                - 风格: 轻松闲聊
                - 深度: 快速浏览

                # 参考内容
                1. 测试文章
                   这是一个测试文章，用于验证豆包播客API的功能。
                """

                // 创建临时输出文件
                let tempDir = FileManager.default.temporaryDirectory
                let audioFileName = "test_podcast_\(UUID().uuidString).mp3"
                let audioURL = tempDir.appendingPathComponent(audioFileName)

                // 调用API
                let service = DoubaoPodcastService(appId: appId, accessToken: accessToken)
                try await service.generatePodcast(
                    inputText: testInput,
                    voiceA: appState.userConfig.doubaoPodcastVoiceA,
                    voiceB: appState.userConfig.doubaoPodcastVoiceB,
                    outputURL: audioURL
                ) { progress in
                    Task { @MainActor in
                        doubaoPodcastTestProgress = progress
                    }
                }

                await MainActor.run {
                    doubaoPodcastTestResult = "✅ 测试成功！音频已生成到: \(audioURL.lastPathComponent)"
                    isTestingDoubaoPodcast = false
                }
            } catch {
                await MainActor.run {
                    doubaoPodcastTestResult = "❌ 测试失败：\(error.localizedDescription)"
                    isTestingDoubaoPodcast = false
                }
            }
        }
    }

}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
