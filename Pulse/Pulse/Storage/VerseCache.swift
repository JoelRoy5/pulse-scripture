import Foundation

// MARK: - Clock Protocol

protocol Clock {
    var now: Date { get }
}

struct SystemClock: Clock {
    var now: Date { Date() }
}

// MARK: - VerseCache

final class VerseCache {
    private let defaults: UserDefaults
    private let clock: Clock

    private let baseCooldown: TimeInterval = 7200     // 2 hours (default)
    private let shortCooldown: TimeInterval = 3600    // 1 hour  (user tapped/engaged)
    private let longCooldown: TimeInterval = 14400    // 4 hours (user dismissed)
    private let maxCacheSize = 50

    private enum Keys {
        static let lastDelivery      = "pulse.lastDelivery"
        static let cooldownDuration  = "pulse.cooldownDuration"
        static let currentVerse      = "pulse.currentVerse"
        static let verseHistory      = "pulse.verseHistory"
    }

    /// Uses the App Group suite by default so iPhone app and Watch extension share state.
    init(clock: Clock = SystemClock(),
         defaults: UserDefaults = UserDefaults(suiteName: "group.com.YOURTEAM.pulse") ?? .standard) {
        self.clock = clock
        self.defaults = defaults
    }

    // MARK: - Cooldown

    /// `true` when enough time has passed since the last delivery.
    var canDeliver: Bool {
        guard let last = defaults.object(forKey: Keys.lastDelivery) as? Date else { return true }
        let stored = defaults.double(forKey: Keys.cooldownDuration)
        let effective = stored > 0 ? stored : baseCooldown
        return clock.now.timeIntervalSince(last) >= effective
    }

    /// `true` between 10 pm and 6 am local time.
    /// During nighttime, delivery should still happen but silently (no haptic).
    var isNighttime: Bool {
        let hour = Calendar.current.component(.hour, from: clock.now)
        return hour >= 22 || hour < 6
    }

    // MARK: - Storage

    /// Stores a delivered verse and resets cooldown to the base (2-hour) duration.
    func store(verse: ScriptureVerse) {
        defaults.set(clock.now, forKey: Keys.lastDelivery)
        defaults.set(baseCooldown, forKey: Keys.cooldownDuration)

        let encoder = JSONEncoder()

        // Current verse (fast single-item access)
        if let data = try? encoder.encode(verse) {
            defaults.set(data, forKey: Keys.currentVerse)
        }

        // Rolling history — keep the most-recent `maxCacheSize` entries
        var history = verseHistory
        history.append(verse)
        if history.count > maxCacheSize {
            history = Array(history.suffix(maxCacheSize))
        }
        if let historyData = try? encoder.encode(history) {
            defaults.set(historyData, forKey: Keys.verseHistory)
        }
    }

    /// Call when the user interacts with the current verse.
    /// - Parameter tapped: `true` if the user tapped/engaged → 1-hour cooldown;
    ///   `false` if the user dismissed → 4-hour cooldown.
    func recordEngagement(tapped: Bool) {
        defaults.set(tapped ? shortCooldown : longCooldown,
                     forKey: Keys.cooldownDuration)
    }

    // MARK: - Retrieval

    /// The most recently stored verse, or `nil` if none has been stored yet.
    var currentVerse: ScriptureVerse? {
        guard let data = defaults.data(forKey: Keys.currentVerse) else { return nil }
        return try? JSONDecoder().decode(ScriptureVerse.self, from: data)
    }

    /// A `SharedVerse` projection of `currentVerse` (for Watch connectivity).
    var currentSharedVerse: SharedVerse? {
        guard let verse = currentVerse else { return nil }
        return SharedVerse(reference: verse.reference,
                           displayLabel: verse.displayLabel,
                           text: verse.text,
                           reflection: verse.reflection,
                           deliveredAt: verse.deliveredAt)
    }

    /// Full delivery history (up to 50 entries, oldest-first).
    var verseHistory: [ScriptureVerse] {
        guard let data = defaults.data(forKey: Keys.verseHistory) else { return [] }
        return (try? JSONDecoder().decode([ScriptureVerse].self, from: data)) ?? []
    }

    /// Explicit nonisolated deinit prevents Swift 6.2 from routing deallocation
    /// through swift_task_deinitOnExecutorImpl (triggered by @MainActor inference
    /// on UserDefaults in the iOS 26 SDK), which causes a runtime crash in tests.
    nonisolated deinit {}
}
