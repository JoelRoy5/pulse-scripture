import SwiftUI

// MARK: - OnboardingView
//
// Three-step onboarding flow shown on first launch.
// Step 0: Welcome — app name and tagline.
// Step 1: HealthKit permission — requests biometric read access.
// Step 2: Translation picker — stores preferred Bible translation to UserDefaults.
// On completion: sets "onboardingComplete" = true, switching PulseApp to SettingsView.

struct OnboardingView: View {
    @Environment(VerseOrchestrator.self) private var orchestrator
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @AppStorage("preferredTranslation") private var preferredTranslation = "NIV"
    @State private var step = 0

    private let translations = ["NIV", "ESV", "KJV", "NLT"]

    var body: some View {
        TabView(selection: $step) {
            welcomeStep.tag(0)
            permissionsStep.tag(1)
            translationStep.tag(2)
        }
        .tabViewStyle(.page)
        .animation(.easeInOut, value: step)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }

    // MARK: - Step 0: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "waveform.path.ecg.rectangle")
                .font(.system(size: 72))
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("Pulse")
                    .font(.largeTitle.bold())
                Text("Scripture at the right moment")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Get Started") {
                withAnimation { step = 1 }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }

    // MARK: - Step 1: HealthKit permissions

    private var permissionsStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "heart.fill")
                .font(.system(size: 64))
                .foregroundStyle(.red)

            VStack(spacing: 8) {
                Text("Health Access")
                    .font(.title2.bold())
                Text("Pulse reads your heart rate, HRV, and sleep data to understand how you're feeling and deliver scripture at the right moment.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Text("Your health data never leaves your device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            Spacer()

            Button("Allow Health Access") {
                Task {
                    try? await HealthKitManager().requestAuthorization()
                    withAnimation { step = 2 }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Continue") {
                withAnimation { step = 2 }
            }
            .foregroundStyle(.secondary)
        }
        .padding()
    }

    // MARK: - Step 2: Translation picker

    private var translationStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "book.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("Your Translation")
                    .font(.title2.bold())
                Text("Which Bible translation do you prefer?")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Picker("Translation", selection: $preferredTranslation) {
                ForEach(translations, id: \.self) { translation in
                    Text(translation).tag(translation)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 140)

            Spacer()

            Button("Start Listening") {
                onboardingComplete = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
}

#Preview {
    OnboardingView()
        .environment(VerseOrchestrator(
            hkManager: PreviewHKManager(),
            glooService: PreviewGlooSvc(),
            youVersion: PreviewYVSvc(),
            preferences: GlooRequest.UserPreferences(translation: "NIV", language: "en")
        ))
}

// MARK: - Preview stubs

private final class PreviewHKManager: HealthKitManagerProtocol {
    func latestHRV() async -> Double?             { nil }
    func latestHeartRate() async -> Double?       { nil }
    func restingHeartRate() async -> Double?      { nil }
    func latestRespiratoryRate() async -> Double? { nil }
    func latestBloodOxygen() async -> Double?     { nil }
    func latestWristTemp() async -> Double?       { nil }
    func sleepSummary(for date: Date) async -> SleepSummary { .empty }
}

private final class PreviewGlooSvc: GlooAPIServiceProtocol {
    func fetchVerse(for classification: EmotionClassification,
                    biometricContext: BiometricContext?,
                    preferences: GlooRequest.UserPreferences) async throws -> GlooResponse {
        GlooResponse(scriptureTheme: "peace", verseReference: "PSA.4.8",
                     verseDisplayLabel: "Psalm 4:8", reflection: "Rest in Him.")
    }
}

private final class PreviewYVSvc: YouVersionAPIServiceProtocol {
    func fetchVerse(reference: String, versionId: Int) async throws -> ScriptureVerse {
        ScriptureVerse(reference: reference, displayLabel: "Psalm 4:8",
                       text: "In peace I will lie down and sleep.", translation: "NIV",
                       reflection: "Rest in Him.", deliveredAt: Date(),
                       emotionalContext: "restful")
    }
}
