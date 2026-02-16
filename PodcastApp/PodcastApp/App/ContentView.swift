import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var audioPlayer: AudioPlayer

    var body: some View {
        Group {
            if appState.isFirstLaunch {
                // 首次启动显示话题选择界面
                OnboardingView()
            } else {
                // 主界面
                MainView()
            }
        }
    }
}

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var audioPlayer: AudioPlayer

    var body: some View {
        VStack(spacing: 0) {
            // 主内容区
            HStack(spacing: 0) {
                // 侧边栏
                Sidebar()
                    .frame(width: 200)

                Divider()

                // 主内容
                mainContent
            }

            Divider()

            // 底部播放控制栏
            if audioPlayer.currentPodcast != nil {
                PlayerControlBar()
                    .frame(height: 80)
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch appState.selectedNavigation {
        case .podcastList:
            PodcastListView()
        case .topics:
            TopicsView()
        case .rss:
            RSSView()
        case .history:
            HistoryView()
        case .settings:
            SettingsView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(RSSService())
        .environmentObject(PodcastService())
        .environmentObject(AudioPlayer())
}
