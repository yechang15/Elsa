import SwiftUI

struct HistoryView: View {
    var body: some View {
        VStack {
            Text("收听历史")
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
    HistoryView()
}
