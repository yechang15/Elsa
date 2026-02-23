import SwiftUI

struct HistoryView: View {
    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack {
                Text("收听历史")
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
    HistoryView()
}
