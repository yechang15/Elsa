import Foundation
import AVFoundation
import Combine

/// 音频播放器
class AudioPlayer: NSObject, ObservableObject {
    private var player: AVPlayer?
    private var timeObserver: Any?

    @Published var currentPodcast: Podcast?
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var playbackRate: Float = 1.0

    override init() {
        super.init()
        setupAudioSession()
    }

    /// 设置音频会话
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    /// 加载并播放播客
    func loadAndPlay(podcast: Podcast, audioURL: URL) {
        // 停止当前播放
        stop()

        // 创建新播放器
        let playerItem = AVPlayerItem(url: audioURL)
        player = AVPlayer(playerItem: playerItem)

        // 设置播放速率
        player?.rate = playbackRate

        // 监听播放进度
        setupTimeObserver()

        // 监听播放完成
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )

        // 更新当前播客
        currentPodcast = podcast

        // 开始播放
        play()
    }

    /// 播放
    func play() {
        player?.play()
        player?.rate = playbackRate
        isPlaying = true
    }

    /// 暂停
    func pause() {
        player?.pause()
        isPlaying = false
    }

    /// 停止
    func stop() {
        player?.pause()
        player = nil
        isPlaying = false
        currentTime = 0
        removeTimeObserver()
    }

    /// 跳转到指定时间
    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime)
    }

    /// 设置播放速率
    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying {
            player?.rate = rate
        }
    }

    /// 上一个播客
    func previous() {
        // TODO: 实现播放列表逻辑
    }

    /// 下一个播客
    func next() {
        // TODO: 实现播放列表逻辑
    }

    /// 设置时间观察器
    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = time.seconds

            if let duration = self?.player?.currentItem?.duration.seconds, duration.isFinite {
                self?.duration = duration
            }
        }
    }

    /// 移除时间观察器
    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }

    /// 播放完成
    @objc private func playerDidFinishPlaying() {
        isPlaying = false
        currentTime = 0

        // 标记播客为已完成
        if let podcast = currentPodcast {
            podcast.isCompleted = true
            podcast.playProgress = 1.0
        }
    }

    deinit {
        removeTimeObserver()
        NotificationCenter.default.removeObserver(self)
    }
}

/// 播放速率选项
extension AudioPlayer {
    static let playbackRates: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    func playbackRateText(_ rate: Float) -> String {
        "\(rate)x"
    }
}
