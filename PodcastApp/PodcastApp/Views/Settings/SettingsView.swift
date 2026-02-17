import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Form {
            Section("LLM 配置") {
                Picker("API 提供商", selection: $appState.userConfig.llmProvider) {
                    Text("豆包").tag("豆包")
                    Text("OpenAI").tag("OpenAI")
                }

                SecureField("API Key", text: $appState.userConfig.llmApiKey)
                    .help("豆包: 从火山引擎控制台获取\nOpenAI: 从 platform.openai.com 获取")

                TextField("模型", text: $appState.userConfig.llmModel)
                    .help("豆包推荐: doubao-seed-2-0-pro-260215\nOpenAI推荐: gpt-4")

                if appState.userConfig.llmProvider == "豆包" {
                    Text("豆包模型示例：doubao-seed-2-0-pro-260215")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("TTS 配置") {
                Picker("TTS 引擎", selection: $appState.userConfig.ttsEngine) {
                    ForEach([TTSEngine.system, .openai, .elevenlabs], id: \.self) { engine in
                        Text(engine.rawValue).tag(engine)
                    }
                }
                
                Slider(value: $appState.userConfig.ttsSpeed, in: 0.5...2.0, step: 0.1) {
                    Text("语速: \(appState.userConfig.ttsSpeed, specifier: "%.1f")x")
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
        .onChange(of: appState.userConfig) { _, _ in
            appState.saveConfig()
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
