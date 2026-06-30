import XCTest
@testable import Pulse

final class BiometricPayloadBuilderTests: XCTestCase {

    // MARK: - HR delta

    func test_hrDelta_calculatedCorrectly() {
        let (features, _) = BiometricPayloadBuilder.build(
            hrv: 20.0, restingHR: 65.0, currentHR: 90.0,
            sleep: .empty, respiratory: nil, bloodOxygen: nil, wristTemp: nil
        )
        XCTAssertEqual(features.hr_delta_from_resting, 25.0, accuracy: 0.01)
    }

    func test_hrDelta_clampedToZeroWhenBelowResting() {
        // currentHR < restingHR should not yield a negative delta
        let (features, _) = BiometricPayloadBuilder.build(
            hrv: nil, restingHR: 70.0, currentHR: 60.0,
            sleep: .empty, respiratory: nil, bloodOxygen: nil, wristTemp: nil
        )
        XCTAssertEqual(features.hr_delta_from_resting, 0.0, accuracy: 0.01)
    }

    // MARK: - Late-night wakefulness

    func test_lateNightWakefulness_setFromSleep() {
        let sleep = SleepSummary(efficiency: 0.6, deepSleepPct: 0.08, remPct: 0.10,
                                  awakeningCount: 2, hadLateNightWakefulness: true)
        let (features, _) = BiometricPayloadBuilder.build(
            hrv: 20.0, restingHR: 65.0, currentHR: 70.0,
            sleep: sleep, respiratory: nil, bloodOxygen: nil, wristTemp: nil
        )
        XCTAssertEqual(features.late_night_wakefulness, 1.0)
    }

    func test_lateNightWakefulness_clearWhenNoWake() {
        let sleep = SleepSummary(efficiency: 0.85, deepSleepPct: 0.2, remPct: 0.2,
                                  awakeningCount: 0, hadLateNightWakefulness: false)
        let (features, _) = BiometricPayloadBuilder.build(
            hrv: 50.0, restingHR: 60.0, currentHR: 62.0,
            sleep: sleep, respiratory: nil, bloodOxygen: nil, wristTemp: nil
        )
        XCTAssertEqual(features.late_night_wakefulness, 0.0)
    }

    // MARK: - Missing / nil inputs

    func test_missingHRV_defaultsToZero() {
        let (features, _) = BiometricPayloadBuilder.build(
            hrv: nil, restingHR: 65.0, currentHR: 70.0,
            sleep: .empty, respiratory: nil, bloodOxygen: nil, wristTemp: nil
        )
        XCTAssertEqual(features.hrv_sdnn, 0.0)
    }

    func test_missingRespiratory_defaultsToZero() {
        let (features, _) = BiometricPayloadBuilder.build(
            hrv: nil, restingHR: nil, currentHR: nil,
            sleep: .empty, respiratory: nil, bloodOxygen: nil, wristTemp: nil
        )
        XCTAssertEqual(features.respiratory_rate, 0.0)
    }

    func test_missingBloodOxygen_defaultsToZero() {
        let (features, _) = BiometricPayloadBuilder.build(
            hrv: nil, restingHR: nil, currentHR: nil,
            sleep: .empty, respiratory: nil, bloodOxygen: nil, wristTemp: nil
        )
        XCTAssertEqual(features.blood_oxygen, 0.0)
    }

    func test_missingWristTemp_defaultsToZero() {
        let (features, _) = BiometricPayloadBuilder.build(
            hrv: nil, restingHR: nil, currentHR: nil,
            sleep: .empty, respiratory: nil, bloodOxygen: nil, wristTemp: nil
        )
        XCTAssertEqual(features.wrist_temp_delta, 0.0)
    }

    // MARK: - Sleep passthrough

    func test_sleepFieldsPassedThrough() {
        let sleep = SleepSummary(efficiency: 0.75, deepSleepPct: 0.18, remPct: 0.22,
                                  awakeningCount: 3, hadLateNightWakefulness: false)
        let (features, _) = BiometricPayloadBuilder.build(
            hrv: nil, restingHR: nil, currentHR: nil,
            sleep: sleep, respiratory: nil, bloodOxygen: nil, wristTemp: nil
        )
        XCTAssertEqual(features.sleep_efficiency, 0.75, accuracy: 0.001)
        XCTAssertEqual(features.deep_sleep_pct, 0.18, accuracy: 0.001)
        XCTAssertEqual(features.rem_pct, 0.22, accuracy: 0.001)
        XCTAssertEqual(features.awakening_count, 3.0, accuracy: 0.001)
    }

    // MARK: - HRV slope

    func test_hrv7DaySlope_zeroWhenFewerThan3Readings() {
        let (features, _) = BiometricPayloadBuilder.build(
            hrv: 40.0, restingHR: nil, currentHR: nil,
            sleep: .empty, respiratory: nil, bloodOxygen: nil, wristTemp: nil,
            previousHRVReadings: [40.0, 42.0]         // only 2 readings
        )
        XCTAssertEqual(features.hrv_7day_slope, 0.0)
    }

    func test_hrv7DaySlope_positiveWhenIncreasing() {
        let (features, _) = BiometricPayloadBuilder.build(
            hrv: 50.0, restingHR: nil, currentHR: nil,
            sleep: .empty, respiratory: nil, bloodOxygen: nil, wristTemp: nil,
            previousHRVReadings: [30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0]
        )
        XCTAssertGreaterThan(features.hrv_7day_slope, 0.0)
    }

    func test_hrv7DaySlope_negativeWhenDecreasing() {
        let (features, _) = BiometricPayloadBuilder.build(
            hrv: 30.0, restingHR: nil, currentHR: nil,
            sleep: .empty, respiratory: nil, bloodOxygen: nil, wristTemp: nil,
            previousHRVReadings: [90.0, 80.0, 70.0, 60.0, 50.0, 40.0, 30.0]
        )
        XCTAssertLessThan(features.hrv_7day_slope, 0.0)
    }

    // MARK: - BiometricContext

    func test_context_hrvSdnn_roundedToOneDecimal() {
        let (_, context) = BiometricPayloadBuilder.build(
            hrv: 42.567, restingHR: nil, currentHR: nil,
            sleep: .empty, respiratory: nil, bloodOxygen: nil, wristTemp: nil
        )
        XCTAssertEqual(context.hrvSdnn, 42.6, accuracy: 0.01)
    }

    func test_context_hrDelta_nilWhenNotPositive() {
        let (_, context) = BiometricPayloadBuilder.build(
            hrv: nil, restingHR: 70.0, currentHR: 65.0,
            sleep: .empty, respiratory: nil, bloodOxygen: nil, wristTemp: nil
        )
        XCTAssertNil(context.hrDelta)
    }

    func test_context_hrvTrend_stable() {
        // No previousHRVReadings → slope = 0.0 → "stable"
        let (_, context) = BiometricPayloadBuilder.build(
            hrv: 45.0, restingHR: nil, currentHR: nil,
            sleep: .empty, respiratory: nil, bloodOxygen: nil, wristTemp: nil
        )
        XCTAssertEqual(context.hrvTrend, "stable")
    }

    // MARK: - Time encoding sanity

    func test_timeEncoding_withinUnitCircle() {
        let (features, _) = BiometricPayloadBuilder.build(
            hrv: nil, restingHR: nil, currentHR: nil,
            sleep: .empty, respiratory: nil, bloodOxygen: nil, wristTemp: nil
        )
        let radius = features.time_of_day_sin * features.time_of_day_sin
                   + features.time_of_day_cos * features.time_of_day_cos
        XCTAssertEqual(radius, 1.0, accuracy: 0.001)
    }
}
