// PulseTests/Mocks/MockVerseCache.swift
import Foundation
@testable import Pulse

final class MockVerseCache: VerseCacheProtocol {
    var canDeliver: Bool = true
    var currentVerse: ScriptureVerse? = nil
    var storedVerse: ScriptureVerse? = nil
    var hoursSinceLastVerse: Double = 0

    func store(verse: ScriptureVerse) {
        storedVerse = verse
        currentVerse = verse
    }

    nonisolated deinit {}
}
