import SwiftUI

struct RSSView: View {
    var body: some View {
        VStack {
            Text("RSS订阅管理")
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
    RSSView()
}
