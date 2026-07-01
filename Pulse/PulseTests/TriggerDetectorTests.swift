import XCTest
@testable import Pulse

final class TriggerDetectorTests: XCTestCase {
    var sut: TriggerDetector!

    override func setUp() {
        super.setUp()
        sut = TriggerDetector()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Core trigger tests

    func test_3amWake_triggersFires() {
        let reason = sut.evaluate(hrv: 15, restingHR: 65, currentHR: 84,
                                  sleep: makeSleep(lateWake: true), hour: 3,
                                  workoutActive: false, canDeliver: true)
        XCTAssertEqual(reason, .lateNightWakefulness)
    }

    func test_workoutActive_suppressesDaytimeTrigger() {
        let reason = sut.evaluate(hrv: 15, restingHR: 65, currentHR: 120,
                                  sleep: .empty, hour: 14,
                                  workoutActive: true, canDeliver: true)
        XCTAssertNil(reason)
    }

    func test_inCooldown_suppressesAllTriggers() {
        let reason = sut.evaluate(hrv: 15, restingHR: 65, currentHR: 90,
                                  sleep: makeSleep(lateWake: true), hour: 3,
                                  workoutActive: false, canDeliver: false)
        XCTAssertNil(reason)
    }

    func test_morningHRV_firesAfterSleep() {
        let reason = sut.evaluate(hrv: 18, restingHR: 65, currentHR: 67,
                                  sleep: makeSleep(lateWake: false), hour: 7,
                                  workoutActive: false, canDeliver: true)
        XCTAssertEqual(reason, .morningHRVAvailable)
    }

    func test_sustainedDaytimeStress_fires() {
        let reason = sut.evaluate(hrv: 22, restingHR: 65, currentHR: 90,
                                  sleep: .empty, hour: 14,
                                  workoutActive: false, canDeliver: true)
        XCTAssertEqual(reason, .sustainedDaytimeStress)
    }

    func test_noTrigger_whenAllNormal() {
        let reason = sut.evaluate(hrv: 50, restingHR: 60, currentHR: 62,
                                  sleep: makeSleep(lateWake: false), hour: 15,
                                  workoutActive: false, canDeliver: true)
        XCTAssertNil(reason)
    }

    // MARK: - Fallback 24-hour tests

    func test_fallback24Hour_firesInMorning() {
        let reason = sut.evaluate(hrv: 50, restingHR: 60, currentHR: 62,
                                  sleep: .empty, hour: 7,
                                  workoutActive: false, canDeliver: true,
                                  hoursSinceLastVerse: 25)
        XCTAssertEqual(reason, .fallback24Hour)
    }

    func test_fallback24Hour_firesAtAnyHour() {
        // Fallback has no time restriction — fires whenever >24h has elapsed
        let reason = sut.evaluate(hrv: 50, restingHR: 60, currentHR: 62,
                                  sleep: .empty, hour: 14,
                                  workoutActive: false, canDeliver: true,
                                  hoursSinceLastVerse: 25)
        XCTAssertEqual(reason, .fallback24Hour)
    }

    // MARK: - Post-workout recovery

    func test_postWorkoutRecovery_fires_whenHRSettling() {
        let reason = sut.evaluate(hrv: 40, restingHR: 65, currentHR: 75,
                                  sleep: .empty, hour: 17,
                                  workoutActive: false, canDeliver: true,
                                  hrWasElevatedPostWorkout: true)
        // hrDelta = 10 < 15 threshold and hrWasElevatedPostWorkout = true
        XCTAssertEqual(reason, .postWorkoutRecovery)
    }

    func test_postWorkoutRecovery_doesNotFire_duringWorkout() {
        let reason = sut.evaluate(hrv: 40, restingHR: 65, currentHR: 75,
                                  sleep: .empty, hour: 17,
                                  workoutActive: true, canDeliver: true,
                                  hrWasElevatedPostWorkout: true)
        XCTAssertNil(reason)
    }

    // MARK: - Priority order

    func test_morningHRV_takesPriorityOverLateNightWakefulness() {
        // hour 5 is in both morningHours (5-9) and nightHours (0-5)
        // morningHRVAvailable is priority 1; lateNightWakefulness is priority 2
        let reason = sut.evaluate(hrv: 18, restingHR: 65, currentHR: 85,
                                  sleep: makeSleep(lateWake: true), hour: 5,
                                  workoutActive: false, canDeliver: true)
        XCTAssertEqual(reason, .morningHRVAvailable)
    }

    // MARK: - Helpers

    private func makeSleep(lateWake: Bool) -> SleepSummary {
        SleepSummary(efficiency: 0.75, deepSleepPct: 0.15, remPct: 0.20,
                     awakeningCount: 1, hadLateNightWakefulness: lateWake)
    }
}
