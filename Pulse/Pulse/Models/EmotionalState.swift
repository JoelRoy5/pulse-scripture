enum EmotionalState: String, CaseIterable {
    case sleepless, anxious, depleted, struggling
    case recovering, restful, resilient, unknown
}

struct EmotionClassification {
    let state: EmotionalState
    let confidence: Double
    let probabilities: [String: Double]

    var isHighConfidence: Bool { confidence >= 0.70 }
}
