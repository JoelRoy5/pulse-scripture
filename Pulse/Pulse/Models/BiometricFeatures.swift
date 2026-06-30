import Foundation

struct BiometricFeatures {
    var hrv_sdnn: Double
    var hrv_7day_slope: Double
    var hr_delta_from_resting: Double
    var sleep_efficiency: Double
    var deep_sleep_pct: Double
    var rem_pct: Double
    var awakening_count: Double
    var late_night_wakefulness: Double
    var respiratory_rate: Double
    var blood_oxygen: Double
    var wrist_temp_delta: Double
    var time_of_day_sin: Double
    var time_of_day_cos: Double

    static func timeEncoding(hour: Int) -> (sin: Double, cos: Double) {
        let angle = 2 * Double.pi * Double(hour) / 24.0
        return (sin: sin(angle), cos: cos(angle))
    }
}
