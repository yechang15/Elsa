import SwiftUI

// 简化的测试应用
@main
struct TextFieldTestApp: App {
    @StateObject private var testState = TestAppState()

    var body: some Scene {
        WindowGroup {
            TextFieldTestView()
                .environmentObject(testState)
                .frame(width: 400, height: 300)
        }
    }
}

// 测试状态
class TestAppState: ObservableObject {
    @Published var config = TestConfig()

    func saveConfig() {
        print("保存配置: apiKey=\(config.apiKey), model=\(config.model)")
    }
}

struct TestConfig: Codable, Equatable {
    var apiKey: String = ""
    var model: String = "doubao-seed-2-0-pro-260215"
}

// 测试视图
struct TextFieldTestView: View {
    @EnvironmentObject var testState: TestAppState

    // 本地状态
    @State private var localApiKey: String = ""
    @State private var localModel: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("TextField 输入测试")
                .font(.title)

            Divider()

            // 方法1: 直接绑定 (可能不工作)
            VStack(alignment: .leading) {
                Text("方法1: 直接绑定到 @Published struct")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("API Key (直接绑定)", text: $testState.config.apiKey)
                    .textFieldStyle(.roundedBorder)

                Text("当前值: \(testState.config.apiKey)")
                    .font(.caption)
            }

            Divider()

            // 方法2: 本地状态 (应该工作)
            VStack(alignment: .leading) {
                Text("方法2: 本地 @State 变量")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("API Key (本地状态)", text: $localApiKey)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: localApiKey) { _, newValue in
                        testState.config.apiKey = newValue
                        testState.saveConfig()
                    }

                Text("当前值: \(localApiKey)")
                    .font(.caption)
            }

            Divider()

            // 方法3: 使用 Binding
            VStack(alignment: .leading) {
                Text("方法3: 自定义 Binding")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("Model", text: Binding(
                    get: { testState.config.model },
                    set: { newValue in
                        testState.config.model = newValue
                        testState.saveConfig()
                    }
                ))
                .textFieldStyle(.roundedBorder)

                Text("当前值: \(testState.config.model)")
                    .font(.caption)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            localApiKey = testState.config.apiKey
            localModel = testState.config.model
        }
    }
}
