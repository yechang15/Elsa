import Foundation
import SwiftData
import UserNotifications

/// 播客自动生成调度服务
class SchedulerService: ObservableObject {
    @Published var isSchedulerActive = false
    @Published var nextScheduledTime: Date?
    @Published var generatingCategories: Set<String> = [] // 正在生成的分类

    private var timer: Timer?
    private let checkInterval: TimeInterval = 60 // 每分钟检查一次
    private let lastGenerationKey = "lastAutoGenerationDate"
    private let topicLastGenerationPrefix = "topicLastGeneration_" // 话题生成时间前缀

    private weak var appState: AppState?
    private weak var podcastService: PodcastService?
    private var modelContext: ModelContext?

    init() {
        // 不在 init 中请求通知权限，避免 bundle 配置问题
    }

    /// 启动调度器
    func start(appState: AppState, podcastService: PodcastService, modelContext: ModelContext) {
        self.appState = appState
        self.podcastService = podcastService
        self.modelContext = modelContext

        guard appState.userConfig.autoGenerate else {
            print("⏸️ 自动生成已禁用")
            return
        }

        stop() // 先停止现有的定时器

        isSchedulerActive = true
        calculateNextScheduledTime()

        // 暂时禁用通知功能，避免开发环境下的 bundle 问题
        // 如果需要通知，可以在正式发布版本中启用
        // if appState.userConfig.notifyNewPodcast {
        //     requestNotificationPermission()
        // }

        // 创建定时器，每分钟检查一次
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.checkAndGenerate()
        }

        // 立即检查一次
        checkAndGenerate()

        // 检查空分类并立即生成
        checkEmptyCategories()

        print("✅ 调度器已启动，下次生成时间: \(nextScheduledTime?.formatted() ?? "未知")")
    }

    /// 停止调度器
    func stop() {
        timer?.invalidate()
        timer = nil
        isSchedulerActive = false
        print("⏹️ 调度器已停止")
    }

    /// 检查并执行生成任务
    private func checkAndGenerate() {
        guard let appState = appState,
              let podcastService = podcastService,
              let modelContext = modelContext else {
            return
        }

        let config = appState.userConfig

        // 1. 检查用户定时生成
        if config.autoGenerate {
            checkUserScheduledGeneration(config: config, modelContext: modelContext, podcastService: podcastService)
        }

        // 2. 检查话题自动生成
        if config.topicAutoGenerate {
            checkTopicAutoGeneration(config: config, modelContext: modelContext, podcastService: podcastService)
        }
    }

    /// 检查用户定时生成
    private func checkUserScheduledGeneration(config: UserConfig, modelContext: ModelContext, podcastService: PodcastService) {
        // 检查是否到了生成时间
        guard shouldGenerateNow(config: config) else {
            return
        }

        // 检查今天是否已经生成过
        if hasGeneratedToday() {
            print("⏭️ 今天已经生成过播客，跳过")
            return
        }

        print("🎙️ 触发用户定时生成播客...")

        // 异步执行生成任务
        Task {
            await generatePodcast(config: config, modelContext: modelContext, podcastService: podcastService)
        }
    }

    /// 检查话题自动生成
    private func checkTopicAutoGeneration(config: UserConfig, modelContext: ModelContext, podcastService: PodcastService) {
        Task {
            do {
                // 获取所有话题
                let descriptor = FetchDescriptor<Topic>()
                let topics = try modelContext.fetch(descriptor)

                guard !topics.isEmpty else {
                    return
                }

                let now = Date()
                let intervalSeconds = TimeInterval(config.topicGenerateInterval * 3600) // 转换为秒

                // 检查每个话题是否需要生成
                for topic in topics {
                    // 检查是否正在生成中
                    let isGenerating = await MainActor.run {
                        generatingCategories.contains(topic.name)
                    }

                    if isGenerating {
                        continue // 跳过正在生成的话题
                    }

                    let lastGenerationKey = topicLastGenerationPrefix + topic.id.uuidString

                    // 获取上次生成时间
                    let lastGeneration = UserDefaults.standard.object(forKey: lastGenerationKey) as? Date

                    // 判断是否需要生成
                    let shouldGenerate: Bool
                    if let lastGeneration = lastGeneration {
                        let timeSinceLastGeneration = now.timeIntervalSince(lastGeneration)
                        shouldGenerate = timeSinceLastGeneration >= intervalSeconds
                    } else {
                        // 从未生成过，立即生成
                        shouldGenerate = true
                    }

                    if shouldGenerate {
                        print("🎙️ 触发话题自动生成: \(topic.name)")

                        // 标记为正在生成
                        await MainActor.run {
                            generatingCategories.insert(topic.name)
                        }

                        // 异步生成单个话题的播客
                        await generateTopicPodcast(
                            topic: topic,
                            config: config,
                            modelContext: modelContext,
                            podcastService: podcastService
                        )

                        // 记录生成时间
                        UserDefaults.standard.set(now, forKey: lastGenerationKey)

                        // 移除生成标记
                        await MainActor.run {
                            generatingCategories.remove(topic.name)
                        }

                        // 每次只生成一个话题，避免同时生成太多
                        break
                    }
                }
            } catch {
                print("❌ 检查话题自动生成失败: \(error)")
            }
        }
    }

    /// 检查空分类并立即生成
    private func checkEmptyCategories() {
        guard let appState = appState,
              let podcastService = podcastService,
              let modelContext = modelContext else {
            return
        }

        let config = appState.userConfig

        Task {
            do {
                // 获取所有播客
                let podcastDescriptor = FetchDescriptor<Podcast>()
                let allPodcasts = try modelContext.fetch(podcastDescriptor)

                // 获取所有已存在的分类
                let existingCategories = Set(allPodcasts.map { $0.displayCategory })

                // 1. 检查"系统推荐"是否为空
                if config.autoGenerate && !existingCategories.contains("系统推荐") {
                    // 检查是否正在生成中
                    let isGenerating = await MainActor.run {
                        generatingCategories.contains("系统推荐")
                    }

                    if !isGenerating {
                        print("🎙️ 检测到系统推荐分类为空，立即生成...")
                        await MainActor.run {
                            generatingCategories.insert("系统推荐")
                        }

                        // 获取所有话题
                        let topicDescriptor = FetchDescriptor<Topic>()
                        let topics = try modelContext.fetch(topicDescriptor)

                        if !topics.isEmpty {
                            await generatePodcast(config: config, modelContext: modelContext, podcastService: podcastService)
                        }

                        await MainActor.run {
                            generatingCategories.remove("系统推荐")
                        }
                    }
                }

                // 2. 检查话题分类是否为空（如果启用了话题自动生成）
                if config.topicAutoGenerate {
                    let topicDescriptor = FetchDescriptor<Topic>()
                    let topics = try modelContext.fetch(topicDescriptor)

                    for topic in topics {
                        if !existingCategories.contains(topic.name) {
                            // 检查是否正在生成中
                            let isGenerating = await MainActor.run {
                                generatingCategories.contains(topic.name)
                            }

                            if isGenerating {
                                continue // 跳过正在生成的话题
                            }

                            print("🎙️ 检测到\(topic.name)分类为空，立即生成...")
                            await MainActor.run {
                                generatingCategories.insert(topic.name)
                            }

                            await generateTopicPodcast(
                                topic: topic,
                                config: config,
                                modelContext: modelContext,
                                podcastService: podcastService
                            )

                            // 记录生成时间
                            let lastGenerationKey = topicLastGenerationPrefix + topic.id.uuidString
                            UserDefaults.standard.set(Date(), forKey: lastGenerationKey)

                            await MainActor.run {
                                generatingCategories.remove(topic.name)
                            }

                            // 每次只生成一个，避免同时生成太多
                            break
                        }
                    }
                }
            } catch {
                print("❌ 检查空分类失败: \(error)")
            }
        }
    }

    /// 判断是否应该现在生成
    private func shouldGenerateNow(config: UserConfig) -> Bool {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: now)

        guard let currentHour = components.hour,
              let currentMinute = components.minute else {
            return false
        }

        // 解析配置的时间 (格式: "HH:mm")
        let timeParts = config.autoGenerateTime.split(separator: ":")
        guard timeParts.count == 2,
              let targetHour = Int(timeParts[0]),
              let targetMinute = Int(timeParts[1]) else {
            return false
        }

        // 检查是否在目标时间的1分钟内
        let isTargetTime = currentHour == targetHour && currentMinute == targetMinute

        if !isTargetTime {
            return false
        }

        // 检查频率
        let weekday = calendar.component(.weekday, from: now)
        switch config.autoGenerateFrequency {
        case .daily:
            return true
        case .weekdays:
            // 周一到周五 (weekday: 2-6)
            return weekday >= 2 && weekday <= 6
        case .weekends:
            // 周六、周日 (weekday: 1, 7)
            return weekday == 1 || weekday == 7
        case .custom:
            // 自定义逻辑可以后续扩展
            return true
        }
    }

    /// 检查今天是否已经生成过
    private func hasGeneratedToday() -> Bool {
        guard let lastGeneration = UserDefaults.standard.object(forKey: lastGenerationKey) as? Date else {
            return false
        }

        let calendar = Calendar.current
        return calendar.isDateInToday(lastGeneration)
    }

    /// 记录生成时间
    private func recordGeneration() {
        UserDefaults.standard.set(Date(), forKey: lastGenerationKey)
    }

    /// 计算下次调度时间
    private func calculateNextScheduledTime() {
        guard let appState = appState else {
            nextScheduledTime = nil
            return
        }

        let config = appState.userConfig
        let calendar = Calendar.current
        let now = Date()

        // 解析配置的时间
        let timeParts = config.autoGenerateTime.split(separator: ":")
        guard timeParts.count == 2,
              let targetHour = Int(timeParts[0]),
              let targetMinute = Int(timeParts[1]) else {
            nextScheduledTime = nil
            return
        }

        // 构建今天的目标时间
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = targetHour
        components.minute = targetMinute
        components.second = 0

        guard var targetDate = calendar.date(from: components) else {
            nextScheduledTime = nil
            return
        }

        // 如果今天的时间已过，找下一个符合频率的日期
        if targetDate <= now || hasGeneratedToday() {
            targetDate = calendar.date(byAdding: .day, value: 1, to: targetDate) ?? targetDate

            // 根据频率找到下一个有效日期
            while !isValidGenerationDate(targetDate, frequency: config.autoGenerateFrequency) {
                targetDate = calendar.date(byAdding: .day, value: 1, to: targetDate) ?? targetDate
            }
        }

        nextScheduledTime = targetDate
    }

    /// 判断日期是否符合生成频率
    private func isValidGenerationDate(_ date: Date, frequency: AutoGenerateFrequency) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)

        switch frequency {
        case .daily:
            return true
        case .weekdays:
            return weekday >= 2 && weekday <= 6
        case .weekends:
            return weekday == 1 || weekday == 7
        case .custom:
            return true
        }
    }

    /// 执行播客生成（所有话题）
    private func generatePodcast(config: UserConfig, modelContext: ModelContext, podcastService: PodcastService) async {
        do {
            print("🎙️ 开始自动生成播客（所有话题）...")

            // 获取所有主题
            let descriptor = FetchDescriptor<Topic>()
            let topics = try modelContext.fetch(descriptor)

            guard !topics.isEmpty else {
                print("⚠️ 没有话题")
                return
            }

            // 设置LLM服务
            podcastService.setupLLM(
                apiKey: config.llmApiKey,
                provider: LLMProvider(rawValue: config.llmProvider) ?? .openai,
                model: config.llmModel
            )

            // 生成播客
            let podcast = try await podcastService.generatePodcast(
                topics: topics,
                config: config,
                modelContext: modelContext,
                category: "系统推荐"
            )

            // 记录生成时间
            recordGeneration()

            // 计算下次生成时间
            await MainActor.run {
                calculateNextScheduledTime()
            }

            print("✅ 自动生成播客成功: \(podcast.title)")
            print("📬 播客已生成: \(podcast.title)")

        } catch {
            print("❌ 自动生成播客失败: \(error)")
        }
    }

    /// 执行单个话题的播客生成
    private func generateTopicPodcast(topic: Topic, config: UserConfig, modelContext: ModelContext, podcastService: PodcastService) async {
        do {
            print("🎙️ 开始生成话题播客: \(topic.name)")

            // 设置LLM服务
            podcastService.setupLLM(
                apiKey: config.llmApiKey,
                provider: LLMProvider(rawValue: config.llmProvider) ?? .openai,
                model: config.llmModel
            )

            // 生成单个话题的播客
            let podcast = try await podcastService.generatePodcast(
                topics: [topic],
                config: config,
                modelContext: modelContext,
                category: topic.name
            )

            print("✅ 话题播客生成成功: \(podcast.title)")
            print("📬 话题播客已生成: \(topic.name) - \(podcast.title)")

        } catch {
            print("❌ 话题播客生成失败 (\(topic.name)): \(error)")
        }
    }

    /// 请求通知权限
    private func requestNotificationPermission() {
        // 在主线程异步执行，避免初始化时的 bundle 问题
        DispatchQueue.main.async {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if granted {
                    print("✅ 通知权限已授予")
                } else if let error = error {
                    print("❌ 通知权限请求失败: \(error)")
                } else {
                    print("⚠️ 通知权限被拒绝")
                }
            }
        }
    }

    /// 发送本地通知
    private func sendNotification(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // 立即发送
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("📬 通知已发送: \(title)")
        } catch {
            print("❌ 发送通知失败: \(error)")
            // 通知失败不影响主流程，只记录日志
        }
    }

    deinit {
        stop()
    }
}
