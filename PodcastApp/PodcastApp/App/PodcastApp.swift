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
    @StateObject private var schedulerService = SchedulerService()

    init() {
        // 初始化SwiftData容器
        do {
            modelContainer = try ModelContainer(for: Topic.self, Podcast.self, RSSFeed.self, ListeningHistory.self, ChatMessage.self)
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
                .environmentObject(schedulerService)
                .modelContainer(modelContainer)
                .frame(minWidth: 1000, minHeight: 600)
                .onAppear {
                    // 启动调度器
                    schedulerService.start(
                        appState: appState,
                        podcastService: podcastService,
                        modelContext: modelContainer.mainContext
                    )

                    // 监听重启调度器的通知
                    NotificationCenter.default.addObserver(
                        forName: .restartScheduler,
                        object: nil,
                        queue: .main
                    ) { _ in
                        schedulerService.start(
                            appState: appState,
                            podcastService: podcastService,
                            modelContext: modelContainer.mainContext
                        )
                    }
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(schedulerService)
        }
    }
}
