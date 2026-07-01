import SwiftUI

// MARK: - SettingsView
//
// Placeholder root view until Task 13 (Onboarding) replaces this with OnboardingView.
// Referenced by PulseApp.swift as the WindowGroup root.

struct SettingsView: View {
    @Environment(VerseOrchestrator.self) private var orchestrator

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "waveform.path.ecg.rectangle")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                Text("Pulse")
                    .font(.largeTitle.bold())

                if let verse = orchestrator.currentVerse {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(verse.displayLabel)
                            .font(.headline)
                        Text(verse.text)
                            .font(.body)
                            .italic()
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                } else {
                    Text("Waiting for your first verse…")
                        .foregroundStyle(.secondary)
                }

                Button("Run Pipeline") {
                    Task { await orchestrator.run() }
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Settings")
            .padding()
        }
    }
}

#Preview {
    SettingsView()
        .environment(VerseOrchestrator(
            hkManager: PreviewHealthKitManager(),
            glooService: PreviewGlooService(),
            youVersion: PreviewYouVersionService(),
            preferences: GlooRequest.UserPreferences(translation: "NIV", language: "en")
        ))
}

// MARK: - Preview stubs

private final class PreviewHealthKitManager: HealthKitManagerProtocol {
    func latestHRV() async -> Double?             { nil }
    func latestHeartRate() async -> Double?       { nil }
    func restingHeartRate() async -> Double?      { nil }
    func latestRespiratoryRate() async -> Double? { nil }
    func latestBloodOxygen() async -> Double?     { nil }
    func latestWristTemp() async -> Double?       { nil }
    func sleepSummary(for date: Date) async -> SleepSummary { .empty }
}

private final class PreviewGlooService: GlooAPIServiceProtocol {
    func fetchVerse(for classification: EmotionClassification,
                    biometricContext: BiometricContext?,
                    preferences: GlooRequest.UserPreferences) async throws -> GlooResponse {
        GlooResponse(scriptureTheme: "peace", verseReference: "PSA.4.8",
                     verseDisplayLabel: "Psalm 4:8", reflection: "Rest in Him.")
    }
}

private final class PreviewYouVersionService: YouVersionAPIServiceProtocol {
    func fetchVerse(reference: String, versionId: Int) async throws -> ScriptureVerse {
        ScriptureVerse(reference: reference, displayLabel: "Psalm 4:8",
                       text: "In peace I will lie down and sleep.", translation: "NIV",
                       reflection: "Rest in Him.", deliveredAt: Date(),
                       emotionalContext: "restful")
    }
}
