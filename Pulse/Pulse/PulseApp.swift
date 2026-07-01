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

    @AppStorage("onboardingComplete") private var onboardingComplete = false

    var body: some Scene {
        WindowGroup {
            Group {
                if onboardingComplete {
                    SettingsView()
                } else {
                    OnboardingView()
                }
            }
            .environment(orchestrator)
            .onAppear {
                // Start HealthKit background delivery after the first view appears.
                // This is safe to call multiple times — HealthKit deduplicates observers.
                // Requires HealthKit authorization to already have been granted (onboarding).
                orchestrator.startBackgroundObservation()
            }
        }
        // BGAppRefresh fallback: iOS wakes the app on its own schedule (~daily).
        // Requires "com.pulse.refresh" in BGTaskSchedulerPermittedIdentifiers (Info.plist).
        .backgroundTask(.appRefresh("com.pulse.refresh")) {
            await orchestrator.run()
        }
    }
}
