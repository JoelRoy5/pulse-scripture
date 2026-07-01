// PulseTests/VerseCacheTests.swift
import XCTest
@testable import Pulse

final class VerseCacheTests: XCTestCase {

    // MARK: - canDeliver

    func test_canDeliverIsTrue_whenNothingDelivered() {
        let cache = VerseCache(clock: MockClock(), defaults: makeDefaults())
        XCTAssertTrue(cache.canDeliver)
    }

    func test_canDeliverIsFalse_withinCooldown() {
        let defaults = makeDefaults()
        let cache = VerseCache(clock: MockClock(), defaults: defaults)
        cache.store(verse: makeVerse())
        XCTAssertFalse(cache.canDeliver)
    }

    func test_canDeliverIsTrue_afterCooldownExpires() {
        let defaults = makeDefaults()
        let cache = VerseCache(clock: MockClock(), defaults: defaults)
        cache.store(verse: makeVerse())
        let later = VerseCache(clock: MockClock(offset: 7201), defaults: defaults)
        XCTAssertTrue(later.canDeliver)
    }

    func test_engagementLowEnough_extendsToShortCooldown_whenTapped() {
        let defaults = makeDefaults()
        let cache = VerseCache(clock: MockClock(), defaults: defaults)
        cache.store(verse: makeVerse())
        cache.recordEngagement(tapped: true)
        // Tapped → shorter cooldown (1 hour = 3600s). At 3601s it should be available.
        let soonAfter = VerseCache(clock: MockClock(offset: 3601), defaults: defaults)
        XCTAssertTrue(soonAfter.canDeliver)
    }

    func test_dismissedVerse_extendsTolongCooldown() {
        let defaults = makeDefaults()
        let cache = VerseCache(clock: MockClock(), defaults: defaults)
        cache.store(verse: makeVerse())
        cache.recordEngagement(tapped: false) // dismissed → 4-hour cooldown
        // At 3601s (past 1h but inside 4h), should still be unavailable
        let inBetween = VerseCache(clock: MockClock(offset: 3601), defaults: defaults)
        XCTAssertFalse(inBetween.canDeliver)
        // At 14401s (past 4h), should be available
        let afterLong = VerseCache(clock: MockClock(offset: 14401), defaults: defaults)
        XCTAssertTrue(afterLong.canDeliver)
    }

    // MARK: - currentVerse

    func test_currentVerse_isNilInitially() {
        let cache = VerseCache(clock: MockClock(), defaults: makeDefaults())
        XCTAssertNil(cache.currentVerse)
    }

    func test_currentVerse_returnsMostRecentlyStored() {
        let cache = VerseCache(clock: MockClock(), defaults: makeDefaults())
        let verse = makeVerse()
        cache.store(verse: verse)
        XCTAssertEqual(cache.currentVerse?.reference, "PSA.4.8")
    }

    func test_currentVerse_updatesOnMultipleStores() {
        let defaults = makeDefaults()
        let cache = VerseCache(clock: MockClock(), defaults: defaults)
        cache.store(verse: makeVerse(reference: "PSA.4.8"))
        cache.store(verse: makeVerse(reference: "ROM.8.28"))
        XCTAssertEqual(cache.currentVerse?.reference, "ROM.8.28")
    }

    // MARK: - verseHistory

    func test_verseHistory_isEmptyInitially() {
        let cache = VerseCache(clock: MockClock(), defaults: makeDefaults())
        XCTAssertTrue(cache.verseHistory.isEmpty)
    }

    func test_verseHistory_growsWithEachStore() {
        let cache = VerseCache(clock: MockClock(), defaults: makeDefaults())
        cache.store(verse: makeVerse(reference: "PSA.4.8"))
        cache.store(verse: makeVerse(reference: "ROM.8.28"))
        XCTAssertEqual(cache.verseHistory.count, 2)
    }

    func test_verseHistory_capsAt50() {
        let cache = VerseCache(clock: MockClock(), defaults: makeDefaults())
        for i in 0..<60 {
            cache.store(verse: makeVerse(reference: "REF.\(i)"))
        }
        XCTAssertEqual(cache.verseHistory.count, 50)
        // Oldest entries should be evicted; most recent should be last
        XCTAssertEqual(cache.verseHistory.last?.reference, "REF.59")
    }

    // MARK: - isNighttime

    func test_isNighttime_trueAt22h() {
        // 10 pm = hour 22
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 22; comps.minute = 0; comps.second = 0
        let date22 = Calendar.current.date(from: comps)!
        let clock = MockClock(offset: date22.timeIntervalSinceNow)
        let cache = VerseCache(clock: clock, defaults: makeDefaults())
        XCTAssertTrue(cache.isNighttime)
    }

    func test_isNighttime_falseAt12h() {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 12; comps.minute = 0; comps.second = 0
        let date12 = Calendar.current.date(from: comps)!
        let clock = MockClock(offset: date12.timeIntervalSinceNow)
        let cache = VerseCache(clock: clock, defaults: makeDefaults())
        XCTAssertFalse(cache.isNighttime)
    }

    // MARK: - Helpers

    private func makeDefaults() -> UserDefaults {
        let suiteName = UUID().uuidString
        let d = UserDefaults(suiteName: suiteName)!
        d.removePersistentDomain(forName: suiteName)
        return d
    }

    private func makeVerse(reference: String = "PSA.4.8") -> ScriptureVerse {
        ScriptureVerse(reference: reference,
                       displayLabel: "Psalm 4:8",
                       text: "In peace I will lie down and sleep",
                       translation: "NIV",
                       reflection: nil,
                       deliveredAt: Date(),
                       emotionalContext: "sleepless")
    }
}
