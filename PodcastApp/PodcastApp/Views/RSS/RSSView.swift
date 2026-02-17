import SwiftUI

struct RSSView: View {
    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack {
                Text("RSS订阅管理")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()
            }
            .padding()

            Divider()

            // 内容区
            VStack {
                Text("功能开发中...")
                    .foregroundColor(.secondary)

                Spacer()
            }
        }
    }
}

#Preview {
    RSSView()
}
