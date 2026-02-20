import Foundation
import SwiftData

// 正在生成的播客状态
class GeneratingPodcast: Identifiable, ObservableObject {
    let id = UUID()
    let topicName: String
    let topics: [Topic]
    let config: UserConfig
    let createdAt: Date

    @Published var currentStep: GenerationStep = .idle
    @Published var stepProgress: Double = 0.0
    @Published var currentStatus: String = ""
    @Published var errorMessage: String?
    @Published var isCompleted: Bool = false
    @Published var generatedPodcast: Podcast?
    @Published var isCancelled: Bool = false

    var generationTask: Task<Void, Never>?

    init(topicName: String, topics: [Topic], config: UserConfig) {
        self.topicName = topicName
        self.topics = topics
        self.config = config
        self.createdAt = Date()
    }

    func cancel() {
        isCancelled = true
        generationTask?.cancel()
    }
}
