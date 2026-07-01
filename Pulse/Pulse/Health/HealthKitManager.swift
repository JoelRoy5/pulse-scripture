import HealthKit

// MARK: - Protocol (enables mocking in tests)

@MainActor
protocol HealthKitManagerProtocol {
    func latestHRV() async -> Double?
    func latestHeartRate() async -> Double?
    func restingHeartRate() async -> Double?
    func latestRespiratoryRate() async -> Double?
    func latestBloodOxygen() async -> Double?
    func latestWristTemp() async -> Double?
    func sleepSummary(for date: Date) async -> SleepSummary
    /// Enables HealthKit background delivery and sets up an observer query so the
    /// app is woken when new HRV or heart-rate samples arrive from the Watch.
    /// `handler` is invoked on every new-data notification; callers should
    /// dispatch non-trivial work to a Task rather than blocking the callback.
    func enableBackgroundDelivery(handler: @escaping () -> Void)
}

// MARK: - Sleep summary

struct SleepSummary {
    let efficiency: Double       // 0.0–1.0
    let deepSleepPct: Double
    let remPct: Double
    let awakeningCount: Double
    let hadLateNightWakefulness: Bool
    static let empty = SleepSummary(efficiency: 0, deepSleepPct: 0,
                                     remPct: 0, awakeningCount: 0,
                                     hadLateNightWakefulness: false)
}

@MainActor
final class HealthKitManager: HealthKitManagerProtocol {
    private let store = HKHealthStore()

    private let readTypes: Set<HKObjectType> = [
        HKQuantityType(.heartRateVariabilitySDNN),
        HKQuantityType(.heartRate),
        HKQuantityType(.restingHeartRate),
        HKQuantityType(.respiratoryRate),
        HKQuantityType(.oxygenSaturation),
        HKQuantityType(.appleSleepingWristTemperature),
        HKCategoryType(.sleepAnalysis)
    ]

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    func latestHRV() async -> Double? {
        await latestQuantity(for: .heartRateVariabilitySDNN, unit: HKUnit(from: "ms"))
    }

    func latestHeartRate() async -> Double? {
        await latestQuantity(for: .heartRate, unit: HKUnit(from: "count/min"))
    }

    func restingHeartRate() async -> Double? {
        await latestQuantity(for: .restingHeartRate, unit: HKUnit(from: "count/min"))
    }

    func latestRespiratoryRate() async -> Double? {
        await latestQuantity(for: .respiratoryRate, unit: HKUnit(from: "count/min"))
    }

    func latestBloodOxygen() async -> Double? {
        guard let raw = await latestQuantity(for: .oxygenSaturation, unit: .percent()) else { return nil }
        return raw * 100.0
    }

    func latestWristTemp() async -> Double? {
        await latestQuantity(for: .appleSleepingWristTemperature, unit: .degreeCelsius())
    }

    func sleepSummary(for date: Date = Date()) async -> SleepSummary {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date).addingTimeInterval(-86400)
        let end = calendar.startOfDay(for: date).addingTimeInterval(43200)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let type = HKCategoryType(.sleepAnalysis)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate,
                                      limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                    continuation.resume(returning: .empty)
                    return
                }
                continuation.resume(returning: Self.computeSleepSummary(from: samples))
            }
            store.execute(query)
        }
    }

    func enableBackgroundDelivery(handler: @escaping () -> Void) {
        let typesToObserve: [HKQuantityTypeIdentifier] = [.heartRateVariabilitySDNN, .heartRate]
        for identifier in typesToObserve {
            let type = HKQuantityType(identifier)
            store.enableBackgroundDelivery(for: type, frequency: .immediate) { _, _ in }
            let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completionHandler, _ in
                handler()
                completionHandler()
            }
            store.execute(query)
        }
    }

    // MARK: - Private helpers

    private func latestQuantity(for identifier: HKQuantityTypeIdentifier,
                                 unit: HKUnit) async -> Double? {
        let type = HKQuantityType(identifier)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let anchor = Date().addingTimeInterval(-86400 * 2)
        let predicate = HKQuery.predicateForSamples(withStart: anchor, end: nil)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate,
                                      limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private static func computeSleepSummary(from samples: [HKCategorySample]) -> SleepSummary {
        var deepSeconds = 0.0
        var remSeconds = 0.0
        var totalSeconds = 0.0
        var awakenings = 0
        var hadLateWake = false

        for sample in samples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)
            switch value {
            case .asleepDeep:  deepSeconds += duration; totalSeconds += duration
            case .asleepREM:   remSeconds += duration; totalSeconds += duration
            case .asleepCore:  totalSeconds += duration
            case .awake:
                awakenings += 1
                let hour = Calendar.current.component(.hour, from: sample.startDate)
                if (0...5).contains(hour) { hadLateWake = true }
            default: break
            }
        }

        let total = max(totalSeconds, 1)
        return SleepSummary(
            efficiency: min(totalSeconds / (totalSeconds + Double(awakenings) * 600), 1.0),
            deepSleepPct: deepSeconds / total,
            remPct: remSeconds / total,
            awakeningCount: Double(awakenings),
            hadLateNightWakefulness: hadLateWake
        )
    }

    enum HealthKitError: Error {
        case notAvailable
    }
}
