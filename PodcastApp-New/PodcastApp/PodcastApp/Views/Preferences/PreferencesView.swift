import SwiftUI
import SwiftData

struct PreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("偏好设置")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button("完成") { dismiss() }
            }
            .padding()

            Divider()

            Picker("", selection: $selectedTab) {
                Text("我的话题").tag(0)
                Text("RSS 订阅").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 12)

            Divider()

            if selectedTab == 0 {
                TopicsView()
            } else {
                RSSView()
            }
        }
        .frame(width: 700, height: 600)
    }
}
