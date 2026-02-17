import SwiftUI
import SwiftData

struct TopicsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Topic.priority, order: .reverse) private var topics: [Topic]
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack {
                Text("兴趣话题管理")
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
    TopicsView()
        .modelContainer(for: [Topic.self])
}
