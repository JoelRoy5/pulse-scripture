import Foundation
import Observation

// MARK: - VerseOrchestrator
//
// Single entry point for the full biometric → emotion → scripture pipeline.
// PulseApp holds a @State reference and calls orchestrator.run() in the background.
// All dependencies are injected as protocols so tests can mock without real
// HealthKit, network, or UserDefaults.
//
// Uses @Observable (Observation framework, iOS 17+) instead of ObservableObject
// because InferIsolatedConformances (enabled in this project) makes ObservableObject
// conformances on @MainActor types fail to satisfy the protocol's nonisolated contract.

@Observable
final class VerseOrchestrator {
    var currentVerse: ScriptureVerse?

    private let hkManager: any HealthKitManagerProtocol
    private let inference: any EmotionInferenceServiceProtocol
    private let glooService: any GlooAPIServiceProtocol
    private let youVersion: any YouVersionAPIServiceProtocol
    private let cache: any VerseCacheProtocol
    private let trigger: any TriggerDetectorProtocol
    private let preferences: GlooRequest.UserPreferences
    private let watchBridge: (any WatchBridgeProtocol)?

    // hkManager has no default: HealthKitManager.init() is explicitly @MainActor and
    // cannot be called from a nonisolated default-parameter-expression context.
    // Callers in a @MainActor context (PulseApp, tests) pass it explicitly.
    init(
        hkManager: any HealthKitManagerProtocol,
        inference: any EmotionInferenceServiceProtocol = EmotionInferenceService(),
        glooService: any GlooAPIServiceProtocol,
        youVersion: any YouVersionAPIServiceProtocol,
        cache: any VerseCacheProtocol = VerseCache(),
        trigger: any TriggerDetectorProtocol = TriggerDetector(),
        preferences: GlooRequest.UserPreferences,
        watchBridge: (any WatchBridgeProtocol)? = nil
    ) {
        self.hkManager = hkManager
        self.inference = inference
        self.glooService = glooService
        self.youVersion = youVersion
        self.cache = cache
        self.trigger = trigger
        self.preferences = preferences
        self.watchBridge = watchBridge
        self.currentVerse = cache.currentVerse
    }

    // MARK: - Pipeline

    func run() async {
        guard cache.canDeliver else { return }

        // Fetch all biometrics concurrently (each awaits its HealthKit callback while
        // the main actor is free to process other work).
        async let hrv         = hkManager.latestHRV()
        async let restingHR   = hkManager.restingHeartRate()
        async let currentHR   = hkManager.latestHeartRate()
        async let sleep       = hkManager.sleepSummary(for: Date())
        async let respiratory = hkManager.latestRespiratoryRate()
        async let bloodOxygen = hkManager.latestBloodOxygen()
        async let wristTemp   = hkManager.latestWristTemp()

        let (hrvVal, restingVal, currentVal, sleepVal, respVal, o2Val, tempVal) =
            await (hrv, restingHR, currentHR, sleep, respiratory, bloodOxygen, wristTemp)

        let hour = Calendar.current.component(.hour, from: Date())

        guard trigger.evaluate(
            hrv: hrvVal, restingHR: restingVal, currentHR: currentVal,
            sleep: sleepVal, hour: hour, workoutActive: false,
            canDeliver: cache.canDeliver,
            hoursSinceLastVerse: cache.hoursSinceLastVerse,
            hrWasElevatedPostWorkout: false
        ) != nil else { return }

        let (features, context) = BiometricPayloadBuilder.build(
            hrv: hrvVal, restingHR: restingVal, currentHR: currentVal,
            sleep: sleepVal, respiratory: respVal,
            bloodOxygen: o2Val, wristTemp: tempVal
        )

        let classification = inference.classify(features: features)

        do {
            let glooResponse = try await glooService.fetchVerse(
                for: classification, biometricContext: context, preferences: preferences
            )
            let verse = try await youVersion.fetchVerse(
                reference: glooResponse.verseReference,
                versionId: versionId(for: preferences.translation)
            )
            let finalVerse = ScriptureVerse(
                reference: verse.reference,
                displayLabel: verse.displayLabel,
                text: verse.text,
                translation: verse.translation,
                reflection: glooResponse.reflection,
                deliveredAt: Date(),
                emotionalContext: classification.state.rawValue
            )
            cache.store(verse: finalVerse)
            currentVerse = finalVerse

            // Push the new verse to the paired Watch.
            let sharedVerse = SharedVerse(
                reference: finalVerse.reference,
                displayLabel: finalVerse.displayLabel,
                text: finalVerse.text,
                reflection: finalVerse.reflection,
                deliveredAt: finalVerse.deliveredAt
            )
            watchBridge?.sendVerse(sharedVerse)
        } catch {
            // Silently fail — never surface errors to the user.
            // Network / API errors are transient; the next scheduled run will retry.
        }
    }

    // MARK: - Helpers

    /// Maps a translation abbreviation to its YouVersion version ID.
    /// Expand this table after July 6 with the full list from the YouVersion API.
    private func versionId(for translation: String) -> Int {
        switch translation {
        case "NIV": return 111
        case "ESV": return 59
        case "NLT": return 116
        case "KJV": return 1
        case "MSG": return 97
        default:    return 111
        }
    }
}
