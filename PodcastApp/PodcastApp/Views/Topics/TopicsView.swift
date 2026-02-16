import SwiftUI
import SwiftData

struct TopicsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Topic.priority, order: .reverse) private var topics: [Topic]
    
    var body: some View {
        VStack {
            Text("兴趣话题管理")
                .font(.title2)
                .fontWeight(.bold)
                .padding()
            
            Text("功能开发中...")
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

#Preview {
    TopicsView()
        .modelContainer(for: [Topic.self])
}
