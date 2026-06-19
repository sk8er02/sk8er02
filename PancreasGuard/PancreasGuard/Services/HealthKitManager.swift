import Foundation
import HealthKit
import Combine

@Observable
final class HealthKitManager {
    private let store = HKHealthStore()

    var isAuthorized = false
    var latestSnapshot: HealthSnapshot?
    var baselines = RiskScoringEngine.Baselines()
    var recentAlcoholDrinks: Double = 0
    var recentDietaryFatGrams: Double = 0

    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws {
        guard isHealthKitAvailable else { return }

        try await store.requestAuthorization(
            toShare: HealthKitQueries.allWriteTypes,
            read: HealthKitQueries.allReadTypes
        )
        isAuthorized = true
        await refreshBaselines()
    }

    func fetchLatestSnapshot() async -> HealthSnapshot {
        let snapshot = HealthSnapshot()

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                snapshot.heartRate = await self.fetchLatest(.heartRate)
            }
            group.addTask {
                snapshot.heartRateVariability = await self.fetchLatest(.heartRateVariabilitySDNN)
            }
            group.addTask {
                snapshot.bloodOxygen = await self.fetchLatest(.oxygenSaturation).map { $0 * 100 }
            }
            group.addTask {
                snapshot.wristTemperature = await self.fetchLatest(.appleSleepingWristTemperature)
            }
            group.addTask {
                snapshot.restingHeartRate = await self.fetchLatest(.restingHeartRate)
            }
            group.addTask {
                snapshot.respiratoryRate = await self.fetchLatest(.respiratoryRate)
            }
            group.addTask {
                snapshot.stepCount = await self.fetchTodaySteps()
            }
        }

        self.latestSnapshot = snapshot
        return snapshot
    }

    func refreshBaselines() async {
        async let avgHR = fetchAverage(.heartRate, days: 7)
        async let avgHRV = fetchAverage(.heartRateVariabilitySDNN, days: 7)
        async let avgSpO2 = fetchAverage(.oxygenSaturation, days: 7)
        async let avgSteps = fetchAverageDailySteps(days: 7)

        let (hr, hrv, spo2, steps) = await (avgHR, avgHRV, avgSpO2, avgSteps)
        if let hr { baselines.averageHeartRate = hr }
        if let hrv { baselines.averageHRV = hrv }
        if let spo2 { baselines.averageSpO2 = spo2 * 100 }
        if let steps { baselines.averageDailySteps = Int(steps) }
    }

    func fetchHeartRateHistory(days: Int) async -> [(Date, Double)] {
        await fetchSamples(.heartRate, days: days)
    }

    func fetchHRVHistory(days: Int) async -> [(Date, Double)] {
        await fetchSamples(.heartRateVariabilitySDNN, days: days)
    }

    // MARK: - Write to Apple Health

    func saveAlcoholToAppleHealth(drinks: Int) async throws {
        let type = HealthKitQueries.alcoholicBeveragesType
        let quantity = HKQuantity(unit: .count(), doubleValue: Double(drinks))
        let sample = HKQuantitySample(type: type, quantity: quantity, start: Date(), end: Date())
        try await store.save(sample)
    }

    func saveDietaryFatToAppleHealth(grams: Double) async throws {
        let type = HealthKitQueries.dietaryFatType
        let quantity = HKQuantity(unit: .gram(), doubleValue: grams)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: Date(), end: Date())
        try await store.save(sample)
    }

    func saveSymptomsToAppleHealth(entry: SymptomEntry) async throws {
        if entry.hasNausea {
            let type = HKCategoryType.categoryType(forIdentifier: .nausea)!
            let sample = HKCategorySample(type: type, value: HKCategoryValueSeverity.moderate.rawValue, start: entry.timestamp, end: entry.timestamp)
            try await store.save(sample)
        }
        if entry.hasVomiting {
            let type = HKCategoryType.categoryType(forIdentifier: .vomiting)!
            let sample = HKCategorySample(type: type, value: HKCategoryValueSeverity.moderate.rawValue, start: entry.timestamp, end: entry.timestamp)
            try await store.save(sample)
        }
        if entry.hasFever {
            let type = HKCategoryType.categoryType(forIdentifier: .fever)!
            let sample = HKCategorySample(type: type, value: HKCategoryValueSeverity.moderate.rawValue, start: entry.timestamp, end: entry.timestamp)
            try await store.save(sample)
        }
        if entry.hasBloating {
            let type = HKCategoryType.categoryType(forIdentifier: .bloating)!
            let sample = HKCategorySample(type: type, value: HKCategoryValueSeverity.moderate.rawValue, start: entry.timestamp, end: entry.timestamp)
            try await store.save(sample)
        }
        if entry.painLevel > 0 {
            let type = HKCategoryType.categoryType(forIdentifier: .abdominalCramps)!
            let severity: HKCategoryValueSeverity = entry.painLevel >= 7 ? .severe : entry.painLevel >= 4 ? .moderate : .mild
            let sample = HKCategorySample(type: type, value: severity.rawValue, start: entry.timestamp, end: entry.timestamp)
            try await store.save(sample)
        }
    }

    // MARK: - Read dietary data from Apple Health (written by any app)
    func fetchDietaryDataFromAppleHealth() async {
        let last24h = Date().addingTimeInterval(-24 * 3600)

        async let alcohol = fetchCumulative(.numberOfAlcoholicBeverages, since: last24h)
        async let fat = fetchCumulative(.dietaryFatTotal, since: last24h)

        let (drinks, fatGrams) = await (alcohol, fat)
        recentAlcoholDrinks = drinks ?? 0
        recentDietaryFatGrams = fatGrams ?? 0
    }

    // MARK: - Private

    private func fetchLatest(_ identifier: HKQuantityTypeIdentifier) async -> Double? {
        let type = HKQuantityType.quantityType(forIdentifier: identifier)!
        return await withCheckedContinuation { continuation in
            HealthKitQueries.latestSample(for: type, store: store) { value in
                continuation.resume(returning: value)
            }
        }
    }

    private func fetchAverage(_ identifier: HKQuantityTypeIdentifier, days: Int) async -> Double? {
        let type = HKQuantityType.quantityType(forIdentifier: identifier)!
        return await withCheckedContinuation { continuation in
            HealthKitQueries.averageOverDays(for: type, days: days, store: store) { value in
                continuation.resume(returning: value)
            }
        }
    }

    private func fetchTodaySteps() async -> Int? {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let type = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        return await withCheckedContinuation { continuation in
            HealthKitQueries.cumulativeSum(for: type, since: startOfDay, store: store) { value in
                continuation.resume(returning: value.map { Int($0) })
            }
        }
    }

    private func fetchAverageDailySteps(days: Int) async -> Double? {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let type = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        return await withCheckedContinuation { continuation in
            HealthKitQueries.cumulativeSum(for: type, since: startDate, store: store) { value in
                continuation.resume(returning: value.map { $0 / Double(days) })
            }
        }
    }

    private func fetchCumulative(_ identifier: HKQuantityTypeIdentifier, since startDate: Date) async -> Double? {
        let type = HKQuantityType.quantityType(forIdentifier: identifier)!
        return await withCheckedContinuation { continuation in
            HealthKitQueries.cumulativeSum(for: type, since: startDate, store: store) { value in
                continuation.resume(returning: value)
            }
        }
    }

    private func fetchSamples(_ identifier: HKQuantityTypeIdentifier, days: Int) async -> [(Date, Double)] {
        let type = HKQuantityType.quantityType(forIdentifier: identifier)!
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return await withCheckedContinuation { continuation in
            HealthKitQueries.samples(for: type, from: startDate, store: store) { samples in
                let unit = HealthKitQueries.preferredUnit(for: type)
                let results = samples.map { ($0.startDate, $0.quantity.doubleValue(for: unit)) }
                continuation.resume(returning: results)
            }
        }
    }
}
