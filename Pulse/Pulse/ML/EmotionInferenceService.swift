import Foundation

// MARK: - EmotionInferenceServiceProtocol

protocol EmotionInferenceServiceProtocol {
    func classify(features: BiometricFeatures) -> EmotionClassification
}

// MARK: - EmotionInferenceService

final class EmotionInferenceService {
    // STUB: Returns rule-based classification until partner's CoreML model is ready.
    // To integrate the real model:
    //   1. Add PulseEmotionClassifier.mlmodel to the ML/ folder
    //   2. Replace this implementation with the CoreML call below
    //
    // Real implementation:
    //   private let model = try! PulseEmotionClassifier(configuration: MLModelConfiguration())
    //   func classify(features: BiometricFeatures) -> EmotionClassification {
    //       let input = PulseEmotionClassifierInput(
    //           hrv_sdnn: features.hrv_sdnn, ... )
    //       let output = try! model.prediction(input: input)
    //       return EmotionClassification(
    //           state: EmotionalState(rawValue: output.emotionalState) ?? .unknown,
    //           confidence: output.emotionalStateProbability[output.emotionalState] ?? 0,
    //           probabilities: output.emotionalStateProbability)
    //   }

    func classify(features: BiometricFeatures) -> EmotionClassification {
        let state = stubClassify(features: features)
        return EmotionClassification(
            state: state,
            confidence: 0.75,
            probabilities: [state.rawValue: 0.75]
        )
    }

    private func stubClassify(features: BiometricFeatures) -> EmotionalState {
        if features.late_night_wakefulness > 0.5 && features.hr_delta_from_resting > 10 {
            return .sleepless
        }
        if features.hr_delta_from_resting > 20 && features.sleep_efficiency < 0.7 {
            return .depleted
        }
        if features.hr_delta_from_resting > 20 {
            return .anxious
        }
        if features.hrv_7day_slope < -0.3 {
            return .struggling
        }
        if features.hrv_sdnn > 45 && features.hr_delta_from_resting < 5 {
            return .restful
        }
        return .unknown
    }
}

extension EmotionInferenceService: EmotionInferenceServiceProtocol {}
