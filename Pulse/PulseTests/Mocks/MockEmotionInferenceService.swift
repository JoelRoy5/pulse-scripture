// PulseTests/Mocks/MockEmotionInferenceService.swift
import Foundation
@testable import Pulse

final class MockEmotionInferenceService: EmotionInferenceServiceProtocol {
    var stubbedState: EmotionalState = .restful

    func classify(features: BiometricFeatures) -> EmotionClassification {
        EmotionClassification(
            state: stubbedState,
            confidence: 0.9,
            probabilities: [stubbedState.rawValue: 0.9]
        )
    }
}
