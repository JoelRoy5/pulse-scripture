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
    private let morningHours = 5...9
    private let nightHours: [Int] = [0, 1, 2, 3, 4, 5]
    private let daytimeHours = 9...22
    private let stressHRDeltaThreshold = 20.0
    private let morningHRVThreshold = 30.0
    private let stressHRVThreshold = 40.0

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

        // Priority 1: Morning HRV — hour 5–9, HRV < 30ms
        if morningHours.contains(hour), let hrv, hrv < morningHRVThreshold, !workoutActive {
            return .morningHRVAvailable
        }

        // Priority 2: Late-night wakefulness — woke during 12am–5am
        if sleep.hadLateNightWakefulness && nightHours.contains(hour) && !workoutActive {
            return .lateNightWakefulness
        }

        // Priority 3: Post-workout recovery — HR elevated post-workout and settling
        if hrWasElevatedPostWorkout && hrDelta < 15 && !workoutActive {
            return .postWorkoutRecovery
        }

        // Priority 4: Sustained daytime stress — HRV < 40ms AND HR elevated AND hour 9–22
        if !workoutActive && daytimeHours.contains(hour),
           let hrv, hrv < stressHRVThreshold,
           hrDelta > stressHRDeltaThreshold {
            return .sustainedDaytimeStress
        }

        // Priority 5: 24h fallback
        if hoursSinceLastVerse >= 24 {
            return .fallback24Hour
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
