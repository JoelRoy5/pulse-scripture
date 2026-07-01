import Foundation

// MARK: - TriggerReason

enum TriggerReason: Equatable {
    case morningHRVAvailable
    case lateNightWakefulness
    case postWorkoutRecovery
    case sustainedDaytimeStress
    case fallback24Hour
}

/// Alias for downstream tasks that reference the dispatcher-brief name.
typealias DeliveryTrigger = TriggerReason

// MARK: - TriggerDetector

final class TriggerDetector {
    private let morningHours = 5...10
    private let nightHours: [Int] = [1, 2, 3, 4, 5]
    private let stressHRDeltaThreshold = 20.0
    private let lateNightHRDeltaThreshold = 15.0

    func evaluate(
        hrv: Double?,
        restingHR: Double?,
        currentHR: Double?,
        sleep: SleepSummary,
        hour: Int,
        workoutActive: Bool,
        canDeliver: Bool,
        hoursSinceLastVerse: Double = 0,
        hrWasElevatedPostWorkout: Bool = false
    ) -> TriggerReason? {
        guard canDeliver else { return nil }

        let hrDelta = (currentHR ?? 0) - (restingHR ?? 0)

        // 24-hour fallback — fires in the morning window if no verse has been delivered
        if hoursSinceLastVerse >= 24 && morningHours.contains(hour) {
            return .fallback24Hour
        }

        // Late-night wakefulness: user woke during 1–5 am with elevated HR
        if sleep.hadLateNightWakefulness && hrDelta > lateNightHRDeltaThreshold
            && nightHours.contains(hour) && !workoutActive {
            return .lateNightWakefulness
        }

        // Morning HRV: HRV data available during morning window, not in a workout
        if morningHours.contains(hour) && hrv != nil && !workoutActive {
            return .morningHRVAvailable
        }

        // Post-workout recovery: HR was elevated after workout and has settled back toward resting
        if hrWasElevatedPostWorkout && hrDelta < 15 && !workoutActive {
            return .postWorkoutRecovery
        }

        // Sustained stress: HR significantly above resting while not in a workout
        if !workoutActive && hrDelta > stressHRDeltaThreshold {
            if nightHours.contains(hour) { return .lateNightWakefulness }
            return .sustainedDaytimeStress
        }

        return nil
    }
}

// MARK: - Static convenience (BiometricFeatures / VerseCache interface)

extension TriggerDetector {
    /// Convenience wrapper that accepts the `BiometricFeatures` struct and a
    /// `VerseCache` instance.  `hour` must be supplied separately because the
    /// time-of-day fields in `BiometricFeatures` are sin/cos encodings designed
    /// for ML inference, not for extracting a precise hour value.
    static func evaluate(
        features: BiometricFeatures,
        cache: VerseCache,
        hoursSinceLastVerse: Double,
        hour: Int,
        workoutActive: Bool = false,
        hrWasElevatedPostWorkout: Bool = false
    ) -> TriggerReason? {
        let detector = TriggerDetector()
        // Reconstruct a minimal SleepSummary from the late_night_wakefulness flag
        let sleep = SleepSummary(
            efficiency: features.sleep_efficiency,
            deepSleepPct: features.deep_sleep_pct,
            remPct: features.rem_pct,
            awakeningCount: features.awakening_count,
            hadLateNightWakefulness: features.late_night_wakefulness == 1.0
        )
        // BiometricFeatures stores hr_delta_from_resting; back-compute currentHR
        // by treating restingHR as a nominal baseline of 0 (delta is the signal).
        return detector.evaluate(
            hrv: features.hrv_sdnn,
            restingHR: 0,
            currentHR: features.hr_delta_from_resting,
            sleep: sleep,
            hour: hour,
            workoutActive: workoutActive,
            canDeliver: cache.canDeliver,
            hoursSinceLastVerse: hoursSinceLastVerse,
            hrWasElevatedPostWorkout: hrWasElevatedPostWorkout
        )
    }
}
