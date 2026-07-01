// PulseTests/Mocks/MockWatchBridge.swift
import Foundation
@testable import Pulse

final class MockWatchBridge: WatchBridgeProtocol {
    var sentVerses: [SharedVerse] = []
    var callCount: Int { sentVerses.count }

    func sendVerse(_ verse: SharedVerse) {
        sentVerses.append(verse)
    }
}
