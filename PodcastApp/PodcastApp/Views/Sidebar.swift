import SwiftUI

struct Sidebar: View {
    @EnvironmentObject var appState: AppState
    @State private var localSelection: NavigationItem = .podcastList

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 应用标题
            Text("播客应用")
                .font(.title2)
                .fontWeight(.bold)
                .padding()

            Divider()

            // 导航列表
            List(selection: $localSelection) {
                ForEach(NavigationItem.allCases, id: \.self) { item in
                    NavigationLink(value: item) {
                        Label(item.rawValue, systemImage: item.icon)
                    }
                }
            }
            .listStyle(.sidebar)
            .onChange(of: localSelection) { oldValue, newValue in
                Task { @MainActor in
                    appState.selectedNavigation = newValue
                }
            }
            .task {
                localSelection = appState.selectedNavigation
            }

            Spacer()
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}

#Preview {
    Sidebar()
        .environmentObject(AppState())
        .frame(width: 200, height: 600)
}
