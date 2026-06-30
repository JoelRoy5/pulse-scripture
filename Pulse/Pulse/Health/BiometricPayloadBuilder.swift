import Foundation

enum BiometricPayloadBuilder {
    static func build(
        hrv: Double?,
        restingHR: Double?,
        currentHR: Double?,
        sleep: SleepSummary,
        respiratory: Double?,
        bloodOxygen: Double?,
        wristTemp: Double?,
        previousHRVReadings: [Double] = []
    ) -> (BiometricFeatures, BiometricContext) {
        let hrDelta: Double = (currentHR != nil && restingHR != nil) ? currentHR! - restingHR! : 0.0
        let hour = Calendar.current.component(.hour, from: Date())
        let timeEnc = BiometricFeatures.timeEncoding(hour: hour)
        let slope = computeHRVSlope(readings: previousHRVReadings)

        let features = BiometricFeatures(
            hrv_sdnn: hrv ?? 0.0,
            hrv_7day_slope: slope,
            hr_delta_from_resting: max(hrDelta, 0),
            sleep_efficiency: sleep.efficiency,
            deep_sleep_pct: sleep.deepSleepPct,
            rem_pct: sleep.remPct,
            awakening_count: sleep.awakeningCount,
            late_night_wakefulness: sleep.hadLateNightWakefulness ? 1.0 : 0.0,
            respiratory_rate: respiratory ?? 0.0,
            blood_oxygen: bloodOxygen ?? 0.0,
            wrist_temp_delta: wristTemp ?? 0.0,
            time_of_day_sin: timeEnc.sin,
            time_of_day_cos: timeEnc.cos
        )

        let context = BiometricContext(
            hrvSdnn: hrv.map { round($0 * 10) / 10 },
            hrDelta: hrDelta > 0 ? round(hrDelta) : nil,
            sleepEfficiency: sleep.efficiency > 0 ? round(sleep.efficiency * 100) / 100 : nil,
            hrvTrend: trendLabel(slope: slope)
        )

        return (features, context)
    }

    // MARK: - HRV slope helpers

    /// Computes a normalized linear-regression slope over the supplied readings.
    /// Returns 0.0 when fewer than 3 readings are available (slope undefined).
    /// Clamps output to [-1.0, 1.0] after dividing raw ms/day slope by 5.0.
    private static func computeHRVSlope(readings: [Double]) -> Double {
        guard readings.count >= 3 else { return 0.0 }
        let n = Double(readings.count)
        let xs = (0..<readings.count).map { Double($0) }
        let meanX = xs.reduce(0, +) / n
        let meanY = readings.reduce(0, +) / n
        let num = zip(xs, readings).map { ($0 - meanX) * ($1 - meanY) }.reduce(0, +)
        let den = xs.map { ($0 - meanX) * ($0 - meanX) }.reduce(0, +)
        let rawSlope = den == 0 ? 0 : num / den
        return max(-1.0, min(1.0, rawSlope / 5.0))
    }

    private static func trendLabel(slope: Double) -> String {
        if slope < -0.2 { return "declining" }
        if slope > 0.2  { return "improving" }
        return "stable"
    }
}
