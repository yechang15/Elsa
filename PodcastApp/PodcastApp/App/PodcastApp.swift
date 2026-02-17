import SwiftUI
import SwiftData

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }
}

@main
struct PodcastApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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

        // 设置应用激活策略
        NSApplication.shared.setActivationPolicy(.regular)
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
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
