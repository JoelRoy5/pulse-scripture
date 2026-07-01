import SwiftUI

// MARK: - SettingsView
//
// Main app screen shown after onboarding completes.
// Displays the current scripture verse, a Bible translation picker,
// a manual trigger button, and a delivery-in-progress indicator.

struct SettingsView: View {
    @Environment(VerseOrchestrator.self) private var orchestrator
    @AppStorage("preferredTranslation") private var preferredTranslation = "NIV"

    private let translations = ["NIV", "ESV", "KJV", "NLT"]

    var body: some View {
        NavigationStack {
            List {
                // MARK: Current verse

                Section("Current Verse") {
                    if let verse = orchestrator.currentVerse {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(verse.text)
                                .font(.callout)
                                .italic()
                            Text(verse.displayLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    } else {
                        Label(
                            "No verse yet — Pulse is listening.",
                            systemImage: "waveform.path.ecg"
                        )
                        .foregroundStyle(.secondary)
                    }
                }

                // MARK: Preferences

                Section("Preferences") {
                    Picker("Translation", selection: $preferredTranslation) {
                        ForEach(translations, id: \.self) { translation in
                            Text(translation).tag(translation)
                        }
                    }
                }

                // MARK: Controls

                Section {
                    Button {
                        Task { await orchestrator.run() }
                    } label: {
                        if orchestrator.isDelivering {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Delivering verse…")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Label("Request verse now", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(orchestrator.isDelivering)
                }
            }
            .navigationTitle("Pulse")
        }
    }
}

#Preview {
    SettingsView()
        .environment(VerseOrchestrator(
            hkManager: SettingsPreviewHKManager(),
            glooService: SettingsPreviewGlooService(),
            youVersion: SettingsPreviewYouVersionService(),
            preferences: GlooRequest.UserPreferences(translation: "NIV", language: "en")
        ))
}

// MARK: - Preview stubs

private final class SettingsPreviewHKManager: HealthKitManagerProtocol {
    func latestHRV() async -> Double?             { nil }
    func latestHeartRate() async -> Double?       { nil }
    func restingHeartRate() async -> Double?      { nil }
    func latestRespiratoryRate() async -> Double? { nil }
    func latestBloodOxygen() async -> Double?     { nil }
    func latestWristTemp() async -> Double?       { nil }
    func sleepSummary(for date: Date) async -> SleepSummary { .empty }
    func enableBackgroundDelivery(handler: @escaping () -> Void) { }
}

private final class SettingsPreviewGlooService: GlooAPIServiceProtocol {
    func fetchVerse(for classification: EmotionClassification,
                    biometricContext: BiometricContext?,
                    preferences: GlooRequest.UserPreferences) async throws -> GlooResponse {
        GlooResponse(scriptureTheme: "peace", verseReference: "PSA.4.8",
                     verseDisplayLabel: "Psalm 4:8", reflection: "Rest in Him.")
    }
}

private final class SettingsPreviewYouVersionService: YouVersionAPIServiceProtocol {
    func fetchVerse(reference: String, versionId: Int) async throws -> ScriptureVerse {
        ScriptureVerse(reference: reference, displayLabel: "Psalm 4:8",
                       text: "In peace I will lie down and sleep.", translation: "NIV",
                       reflection: "Rest in Him.", deliveredAt: Date(),
                       emotionalContext: "restful")
    }
}
