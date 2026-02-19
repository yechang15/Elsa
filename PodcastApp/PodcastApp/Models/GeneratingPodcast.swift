import Foundation
import SwiftData

// 正在生成的播客状态
class GeneratingPodcast: Identifiable, ObservableObject {
    let id = UUID()
    let topicName: String
    let topics: [Topic]

    @Published var currentStep: GenerationStep = .idle
    @Published var stepProgress: Double = 0.0
    @Published var currentStatus: String = ""
    @Published var errorMessage: String?
    @Published var isCompleted: Bool = false
    @Published var generatedPodcast: Podcast?

    init(topicName: String, topics: [Topic]) {
        self.topicName = topicName
        self.topics = topics
    }
}
