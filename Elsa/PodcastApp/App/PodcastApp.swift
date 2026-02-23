import SwiftUI
import SwiftData

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }
}

@main
struct ElsaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // SwiftData模型容器
    let modelContainer: ModelContainer

    // 全局服务
    @StateObject private var appState = AppState()
    @StateObject private var rssService = RSSService()
    @StateObject private var podcastService = PodcastService()
    @StateObject private var audioPlayer = AudioPlayer()
    @StateObject private var schedulerService = SchedulerService()
    @StateObject private var behaviorTracker: BehaviorTracker
    @StateObject private var memoryManager: MemoryManager

    init() {
        // 初始化SwiftData容器
        do {
            modelContainer = try ModelContainer(
                for: Topic.self,
                     Podcast.self,
                     RSSFeed.self,
                     ListeningHistory.self,
                     ChatMessage.self,
                     UserBehaviorEvent.self,
                     PlaybackSession.self,
                     ContentInteraction.self,
                     TopicPreference.self
            )
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }

        // 初始化行为追踪器
        let tracker = BehaviorTracker(modelContext: modelContainer.mainContext)
        _behaviorTracker = StateObject(wrappedValue: tracker)

        // 初始化记忆管理器
        let memory = MemoryManager(modelContext: modelContainer.mainContext, behaviorTracker: tracker)
        _memoryManager = StateObject(wrappedValue: memory)

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
                .environmentObject(behaviorTracker)
                .environmentObject(memoryManager)
                .modelContainer(modelContainer)
                .frame(minWidth: 1000, minHeight: 600)
                .onAppear {
                    // 将行为追踪器注入到AudioPlayer
                    audioPlayer.behaviorTracker = behaviorTracker

                    // 将行为追踪器注入到PodcastService
                    podcastService.behaviorTracker = behaviorTracker

                    // 将记忆管理器注入到PodcastService
                    podcastService.memoryManager = memoryManager

                    // 建立 BehaviorTracker 和 MemoryManager 的双向引用
                    behaviorTracker.memoryManager = memoryManager

                    // 启动调度器
                    schedulerService.start(
                        appState: appState,
                        podcastService: podcastService,
                        modelContext: modelContainer.mainContext
                    )

                    // 监听重启调度器的通知
                    let mainContext = modelContainer.mainContext
                    NotificationCenter.default.addObserver(
                        forName: .restartScheduler,
                        object: nil,
                        queue: .main
                    ) { _ in
                        schedulerService.start(
                            appState: appState,
                            podcastService: podcastService,
                            modelContext: mainContext
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
