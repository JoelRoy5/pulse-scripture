import SwiftUI

@main
struct PulseApp: App {
    // @Observable + @State: the recommended pattern for iOS 17+ reference-type
    // models. PulseApp is @MainActor, so HealthKitManager() is safe here.
    @State private var orchestrator = VerseOrchestrator(
        hkManager: HealthKitManager(),
        glooService: GlooAPIService(apiKey: Secrets.glooAPIKey),
        youVersion: YouVersionAPIService(apiKey: Secrets.youVersionAPIKey),
        preferences: GlooRequest.UserPreferences(translation: "NIV", language: "en"),
        watchBridge: PhoneSessionManager.shared
    )

    var body: some Scene {
        WindowGroup {
            // OnboardingView added in Task 13 — SettingsView is the root until then.
            SettingsView()
                .environment(orchestrator)
        }
    }
}
