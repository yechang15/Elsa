import SwiftUI

struct ToolsManagementView: View {
    @StateObject private var viewModel = ToolsViewModel()
    @State private var selectedTool: ToolInfo?
    @State private var showingTestSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                Text("工具")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button(action: {
                    // TODO: 添加工具
                }) {
                    Label("添加工具", systemImage: "plus")
                }
                .disabled(true)  // P2 暂不支持添加工具
            }
            .padding()

            Divider()

            // 工具列表
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(viewModel.tools) { tool in
                        ToolCard(tool: tool, viewModel: viewModel)
                    }
                }
                .padding()
            }
        }
        .onAppear {
            viewModel.refreshPermissions()
        }
        #if os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // 从系统设置返回时刷新权限状态
            viewModel.refreshPermissions()
        }
        #endif
    }
}

// MARK: - ToolCard

struct ToolCard: View {
    let tool: ToolInfo
    @ObservedObject var viewModel: ToolsViewModel
    @State private var showingTestSheet = false
    @State private var testResult: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack {
                Text("\(tool.status.icon) \(tool.name) (\(tool.id))")
                    .font(.headline)
                Spacer()
                Text(tool.type)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }

            // 描述
            Text(tool.description)
                .font(.subheadline)
                .foregroundColor(.secondary)

            // 权限状态
            if tool.needsPermission {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(tool.permissions) { permission in
                        HStack {
                            Text("\(permission.icon) \(permission.name)：")
                                .font(.caption)
                            Text(permission.status.description)
                                .font(.caption)
                                .foregroundColor(permission.status == .authorized ? .green : .orange)

                            if permission.status != .authorized {
                                Button("前往系统设置") {
                                    viewModel.openSystemSettings(for: permission.name)
                                }
                                .font(.caption)
                                .buttonStyle(.link)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }

            // 操作按钮
            HStack {
                Button("测试") {
                    testTool()
                }
                .buttonStyle(.bordered)

                Button("配置") {
                    // TODO: 配置工具
                }
                .buttonStyle(.bordered)
                .disabled(true)  // P2 暂不支持配置
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .sheet(isPresented: $showingTestSheet) {
            TestResultSheet(toolName: tool.name, result: testResult)
        }
    }

    private func testTool() {
        testResult = "正在测试 \(tool.name)..."
        showingTestSheet = true

        Task {
            // TODO: 实际调用工具的 execute() 方法
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            testResult = "工具 \(tool.name) 测试成功\n\n返回示例数据..."
        }
    }
}

// MARK: - TestResultSheet

struct TestResultSheet: View {
    let toolName: String
    let result: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("测试结果：\(toolName)")
                    .font(.headline)
                Spacer()
                Button("关闭") {
                    dismiss()
                }
            }

            Divider()

            ScrollView {
                Text(result)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .frame(width: 500, height: 400)
    }
}

#Preview {
    ToolsManagementView()
        .frame(width: 800, height: 600)
}
