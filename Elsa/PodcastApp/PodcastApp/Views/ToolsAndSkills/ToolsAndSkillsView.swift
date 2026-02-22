import SwiftUI

struct ToolsAndSkillsView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab 选择器
            Picker("", selection: $selectedTab) {
                Text("工具").tag(0)
                Text("技能（Skills）").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            // Tab 内容
            TabView(selection: $selectedTab) {
                ToolsManagementView()
                    .tag(0)

                SkillsManagementView()
                    .tag(1)
            }
            .tabViewStyle(.automatic)
        }
    }
}

#Preview {
    ToolsAndSkillsView()
        .frame(width: 900, height: 700)
}
