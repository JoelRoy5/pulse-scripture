import XCTest
@testable import Pulse

final class EmotionInferenceTests: XCTestCase {
    var sut: EmotionInferenceService!

    override func setUp() {
        sut = EmotionInferenceService()
    }

    func test_classify_returnsClassification() {
        let features = makeFeatures(hrvSdnn: 17.0, hrDelta: 22.0, hour: 3)
        let result = sut.classify(features: features)
        XCTAssertNotNil(result)
        XCTAssertGreaterThanOrEqual(result.confidence, 0.0)
        XCTAssertLessThanOrEqual(result.confidence, 1.0)
    }

    func test_classify_returnsValidState() {
        let features = makeFeatures(hrvSdnn: 17.0, hrDelta: 22.0, hour: 3)
        let result = sut.classify(features: features)
        XCTAssertTrue(EmotionalState.allCases.contains(result.state))
    }

    // MARK: - Helpers

    private func makeFeatures(hrvSdnn: Double, hrDelta: Double, hour: Int) -> BiometricFeatures {
        let timeEnc = BiometricFeatures.timeEncoding(hour: hour)
        return BiometricFeatures(
            hrv_sdnn: hrvSdnn,
            hrv_7day_slope: 0.0,
            hr_delta_from_resting: hrDelta,
            sleep_efficiency: 0.6,
            deep_sleep_pct: 0.08,
            rem_pct: 0.12,
            awakening_count: 3,
            late_night_wakefulness: hour >= 1 && hour <= 5 ? 1.0 : 0.0,
            respiratory_rate: 18.0,
            blood_oxygen: 96.0,
            wrist_temp_delta: 0.0,
            time_of_day_sin: timeEnc.sin,
            time_of_day_cos: timeEnc.cos
        )
    }
}
