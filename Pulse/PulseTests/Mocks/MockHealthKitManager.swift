// PulseTests/Mocks/MockHealthKitManager.swift
import Foundation
@testable import Pulse

@MainActor
final class MockHealthKitManager: HealthKitManagerProtocol {
    var stubbedHRV: Double?             = nil
    var stubbedHeartRate: Double?       = nil
    var stubbedRestingHR: Double?       = nil
    var stubbedRespiratoryRate: Double? = nil
    var stubbedBloodOxygen: Double?     = nil
    var stubbedWristTemp: Double?       = nil
    var stubbedSleep: SleepSummary      = .empty

    var backgroundDeliveryCallCount = 0
    var capturedHandler: (() -> Void)?

    func latestHRV() async -> Double?            { stubbedHRV }
    func latestHeartRate() async -> Double?      { stubbedHeartRate }
    func restingHeartRate() async -> Double?     { stubbedRestingHR }
    func latestRespiratoryRate() async -> Double? { stubbedRespiratoryRate }
    func latestBloodOxygen() async -> Double?    { stubbedBloodOxygen }
    func latestWristTemp() async -> Double?      { stubbedWristTemp }
    func sleepSummary(for date: Date) async -> SleepSummary { stubbedSleep }
    func enableBackgroundDelivery(handler: @escaping () -> Void) {
        backgroundDeliveryCallCount += 1
        capturedHandler = handler
    }
}
