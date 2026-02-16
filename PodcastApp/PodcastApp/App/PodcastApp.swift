import SwiftUI
import SwiftData

@main
struct PodcastApp: App {
    // SwiftData模型容器
    let modelContainer: ModelContainer

    // 全局服务
    @StateObject private var appState = AppState()
    @StateObject private var rssService = RSSService()
    @StateObject private var podcastService = PodcastService()
    @StateObject private var audioPlayer = AudioPlayer()

    init() {
        // 初始化SwiftData容器
        do {
            modelContainer = try ModelContainer(for: Topic.self, Podcast.self, RSSFeed.self, ListeningHistory.self)
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(rssService)
                .environmentObject(podcastService)
                .environmentObject(audioPlayer)
                .modelContainer(modelContainer)
                .frame(minWidth: 1000, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            // 自定义菜单命令
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
