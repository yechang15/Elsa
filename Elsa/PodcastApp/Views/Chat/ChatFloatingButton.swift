import SwiftUI

/// 全局浮动对话按钮
struct ChatFloatingButton: View {
    @Binding var isShowingChat: Bool

    var body: some View {
        Button(action: {
            isShowingChat.toggle()
        }) {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 56, height: 56)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)

                Image(systemName: "message.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
    }
}
