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
        // macOS 不需要设置 AVAudioSession
    }

    /// 加载并播放播客
    func loadAndPlay(podcast: Podcast, audioURL: URL) {
        print("=== 开始加载播客 ===")
        print("播客标题: \(podcast.title)")
        print("音频路径: \(audioURL.path)")
        print("文件是否存在: \(FileManager.default.fileExists(atPath: audioURL.path))")

        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            print("❌ 音频文件不存在")
            return
        }

        // 检查文件大小
        if let attributes = try? FileManager.default.attributesOfItem(atPath: audioURL.path),
           let fileSize = attributes[.size] as? Int64 {
            print("文件大小: \(fileSize) 字节")
        }

        // 停止当前播放
        stop()

        // 创建新播放器
        let playerItem = AVPlayerItem(url: audioURL)
        player = AVPlayer(playerItem: playerItem)

        // 监听播放器状态
        playerItem.addObserver(self, forKeyPath: "status", options: [.new], context: nil)

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
        print("开始播放...")
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
            guard let self = self else { return }

            self.currentTime = time.seconds

            if let duration = self.player?.currentItem?.duration.seconds, duration.isFinite {
                self.duration = duration

                // 同步更新播客的播放进度
                if let podcast = self.currentPodcast, duration > 0 {
                    podcast.playProgress = time.seconds / duration
                }
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

    /// 监听播放器状态变化
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
            if let playerItem = object as? AVPlayerItem {
                switch playerItem.status {
                case .readyToPlay:
                    print("✅ 播放器准备就绪")
                    Task {
                        if let duration = try? await playerItem.asset.load(.duration).seconds, duration.isFinite {
                            print("音频时长: \(duration) 秒")
                            // 立即更新duration，确保进度条能正确显示
                            await MainActor.run {
                                self.duration = duration
                            }
                        }
                    }
                case .failed:
                    print("❌ 播放器加载失败")
                    if let error = playerItem.error {
                        print("错误: \(error.localizedDescription)")
                    }
                case .unknown:
                    print("⚠️ 播放器状态未知")
                @unknown default:
                    break
                }
            }
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
