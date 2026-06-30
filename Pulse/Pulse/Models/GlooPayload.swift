struct GlooRequest: Encodable {
    let emotionalState: String
    let stateConfidence: Double
    let supportingSignals: SupportingSignals
    let timeContext: TimeContext
    let userPreferences: UserPreferences

    struct SupportingSignals: Encodable {
        let hrvSdnnMs: Double?
        let hrDeltaBpm: Double?
        let lateNightWake: Bool
        let sleepEfficiency: Double?
        let hrvTrend: String
    }

    struct TimeContext: Encodable {
        let timeOfDay: String
        let dayOfWeek: String
    }

    struct UserPreferences: Encodable {
        let translation: String
        let language: String
    }
}

struct GlooResponse: Decodable {
    let scriptureTheme: String
    let verseReference: String
    let verseDisplayLabel: String
    let reflection: String?
}
