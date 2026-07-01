// PulseTests/Mocks/MockTriggerDetector.swift
import Foundation
@testable import Pulse

final class MockTriggerDetector: TriggerDetectorProtocol {
    var stubbedReason: TriggerReason? = .fallback24Hour

    func evaluate(
        hrv: Double?,
        restingHR: Double?,
        currentHR: Double?,
        sleep: SleepSummary,
        hour: Int,
        workoutActive: Bool,
        canDeliver: Bool,
        hoursSinceLastVerse: Double,
        hrWasElevatedPostWorkout: Bool
    ) -> TriggerReason? {
        stubbedReason
    }
}
