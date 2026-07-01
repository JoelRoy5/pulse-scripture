import WidgetKit
import Foundation

/// Provides timeline entries to `VerseWidget`.
/// Reads a cached `SharedVerse` from the shared App Group UserDefaults written
/// by `WatchSessionManager` whenever a new verse arrives from the iPhone.
struct VerseTimelineProvider: TimelineProvider {

    // MARK: - TimelineProvider

    func placeholder(in context: Context) -> VerseEntry {
        VerseEntry(
            date: Date(),
            verse: SharedVerse(
                reference: "Psalm 46:10",
                displayLabel: "Psalm 46:10 (NIV)",
                text: "Be still, and know that I am God.",
                reflection: nil,
                deliveredAt: Date()
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (VerseEntry) -> Void) {
        completion(VerseEntry(date: Date(), verse: loadCachedVerse()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VerseEntry>) -> Void) {
        // Policy `.never` — the widget stays current until `WatchSessionManager`
        // calls `WidgetCenter.shared.reloadAllTimelines()` on a new verse.
        let entry = VerseEntry(date: Date(), verse: loadCachedVerse())
        completion(Timeline(entries: [entry], policy: .never))
    }

    // MARK: - Private

    private func loadCachedVerse() -> SharedVerse? {
        guard
            let defaults = UserDefaults(suiteName: "group.com.YOURTEAM.pulse"),
            let data = defaults.data(forKey: SharedVerse.watchContextKey)
        else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SharedVerse.self, from: data)
    }
}
