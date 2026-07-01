// PulseTests/Mocks/MockClock.swift
import Foundation
@testable import Pulse

struct MockClock: Clock {
    let fixedDate: Date
    var now: Date { fixedDate }

    init(offset: TimeInterval = 0) {
        fixedDate = Date().addingTimeInterval(offset)
    }
}
