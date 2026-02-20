import SwiftUI
import SwiftData

struct PlayerControlBar: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    @Query(sort: \Podcast.createdAt, order: .reverse) private var allPodcasts: [Podcast]

    var body: some View {
        HStack(spacing: 20) {
            // 播放/暂停按钮
            Button(action: togglePlayPause) {
                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)

            // 播客标题
            if let podcast = audioPlayer.currentPodcast {
                Text(podcast.title)
                    .font(.body)
                    .lineLimit(1)
            }

            Spacer()

            // 进度条
            HStack(spacing: 8) {
                Text(formatTime(audioPlayer.currentTime))
                    .font(.caption)
                    .monospacedDigit()

                Slider(
                    value: Binding(
                        get: { audioPlayer.currentTime },
                        set: { audioPlayer.seek(to: $0) }
                    ),
                    in: 0...max(audioPlayer.duration, 1)
                )
                .frame(width: 200)

                Text(formatTime(audioPlayer.duration))
                    .font(.caption)
                    .monospacedDigit()
            }

            Spacer()

            // 音量控制
            Image(systemName: "speaker.wave.2.fill")
                .font(.body)

            // 播放完成策略
            Menu {
                ForEach(PlaybackMode.allCases, id: \.self) { mode in
                    Button {
                        audioPlayer.playbackMode = mode
                    } label: {
                        Label(mode.rawValue, systemImage: mode.icon)
                    }
                }
            } label: {
                Image(systemName: audioPlayer.playbackMode.icon)
                    .font(.body)
                    .foregroundStyle(audioPlayer.playbackMode == .none ? .secondary : .primary)
            }

            // 倍速控制
            Menu {
                ForEach(AudioPlayer.playbackRates, id: \.self) { rate in
                    Button(audioPlayer.playbackRateText(rate)) {
                        audioPlayer.setPlaybackRate(rate)
                    }
                }
            } label: {
                Text(audioPlayer.playbackRateText(audioPlayer.playbackRate))
                    .font(.body)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            audioPlayer.currentPlaylist = allPodcasts
        }
        .onChange(of: allPodcasts) { _, newValue in
            audioPlayer.currentPlaylist = newValue
        }
    }

    private func togglePlayPause() {
        if audioPlayer.isPlaying {
            audioPlayer.pause()
        } else {
            audioPlayer.play()
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

#Preview {
    PlayerControlBar()
        .environmentObject(AudioPlayer())
        .frame(height: 80)
}
