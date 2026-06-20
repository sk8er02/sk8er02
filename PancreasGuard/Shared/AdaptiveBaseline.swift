import Foundation
import SwiftData

@Model
final class DailyBiometricSummary {
    var id: UUID
    var date: Date
    var avgHeartRate: Double?
    var restingHeartRate: Double?
    var avgHRV: Double?
    var avgSpO2: Double?
    var stepCount: Int?
    var wristTemperature: Double?
    var dayOfWeek: Int
    var hadFlareEvent: Bool

    init(date: Date, dayOfWeek: Int = 0) {
        self.id = UUID()
        self.date = date
        self.dayOfWeek = dayOfWeek
        self.hadFlareEvent = false
    }
}

struct PersonalizedThresholds {
    var restingHRAlert: Double
    var heartRateAlert: Double
    var hrvDropPercentAlert: Double
    var spo2Alert: Double
    var stepDropPercentAlert: Double
    var temperatureAlert: Double

    static let defaults = PersonalizedThresholds(
        restingHRAlert: 100,
        heartRateAlert: 110,
        hrvDropPercentAlert: 30,
        spo2Alert: 92,
        stepDropPercentAlert: 50,
        temperatureAlert: 1.0
    )
}

struct AdaptiveBaselineEngine {
    private let history: [DailyBiometricSummary]

    init(history: [DailyBiometricSummary]) {
        self.history = history.filter { !$0.hadFlareEvent }
    }

    func computeThresholds() -> PersonalizedThresholds {
        guard history.count >= 14 else { return .defaults }

        let rhrValues = history.compactMap(\.restingHeartRate)
        let hrvValues = history.compactMap(\.avgHRV)
        let spo2Values = history.compactMap(\.avgSpO2)
        let stepValues = history.compactMap(\.stepCount).map(Double.init)

        return PersonalizedThresholds(
            restingHRAlert: personalizedThreshold(
                values: rhrValues,
                defaultValue: 100,
                sigmas: 2.5,
                floor: 85,
                ceiling: 110
            ),
            heartRateAlert: personalizedThreshold(
                values: history.compactMap(\.avgHeartRate),
                defaultValue: 110,
                sigmas: 2.5,
                floor: 95,
                ceiling: 120
            ),
            hrvDropPercentAlert: personalizedHRVDropThreshold(hrvValues: hrvValues),
            spo2Alert: personalizedFloorThreshold(
                values: spo2Values,
                defaultValue: 92,
                sigmas: 2.0,
                floor: 88,
                ceiling: 95
            ),
            stepDropPercentAlert: personalizedStepDropThreshold(stepValues: stepValues),
            temperatureAlert: personalizedThreshold(
                values: history.compactMap(\.wristTemperature),
                defaultValue: 1.0,
                sigmas: 2.0,
                floor: 0.5,
                ceiling: 1.5
            )
        )
    }

    // Alert when value is N sigma above personal mean
    private func personalizedThreshold(values: [Double], defaultValue: Double, sigmas: Double, floor: Double, ceiling: Double) -> Double {
        guard values.count >= 14 else { return defaultValue }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count)
        let sd = sqrt(variance)
        return min(ceiling, max(floor, mean + sigmas * sd))
    }

    // Alert when value drops below N sigma from personal mean
    private func personalizedFloorThreshold(values: [Double], defaultValue: Double, sigmas: Double, floor: Double, ceiling: Double) -> Double {
        guard values.count >= 14 else { return defaultValue }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count)
        let sd = sqrt(variance)
        return min(ceiling, max(floor, mean - sigmas * sd))
    }

    private func personalizedHRVDropThreshold(hrvValues: [Double]) -> Double {
        guard hrvValues.count >= 14 else { return 30 }
        let mean = hrvValues.reduce(0, +) / Double(hrvValues.count)
        let variance = hrvValues.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(hrvValues.count)
        let cv = sqrt(variance) / mean * 100
        // If HRV is naturally variable (high CV), require a larger drop to alert
        // If HRV is stable (low CV), a smaller drop is more meaningful
        return min(50, max(20, cv * 2.5))
    }

    private func personalizedStepDropThreshold(stepValues: [Double]) -> Double {
        guard stepValues.count >= 14 else { return 50 }
        let mean = stepValues.reduce(0, +) / Double(stepValues.count)
        let variance = stepValues.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(stepValues.count)
        let cv = sqrt(variance) / mean * 100
        // Same idea: naturally variable step counts need a larger drop to trigger
        return min(70, max(30, cv * 1.5))
    }

    // Day-of-week adjusted baselines — handles "Sunday effect" (lower activity, higher RHR)
    func dayAdjustedBaseline(for dayOfWeek: Int) -> RiskScoringEngine.Baselines {
        let dayHistory = history.filter { $0.dayOfWeek == dayOfWeek }
        let allHistory = history

        func avg(_ values: [Double]) -> Double? {
            guard !values.isEmpty else { return nil }
            return values.reduce(0, +) / Double(values.count)
        }

        var baselines = RiskScoringEngine.Baselines()

        baselines.averageHeartRate = avg(dayHistory.compactMap(\.avgHeartRate))
            ?? avg(allHistory.compactMap(\.avgHeartRate))
            ?? baselines.averageHeartRate

        baselines.averageHRV = avg(dayHistory.compactMap(\.avgHRV))
            ?? avg(allHistory.compactMap(\.avgHRV))
            ?? baselines.averageHRV

        baselines.averageSpO2 = avg(dayHistory.compactMap(\.avgSpO2))
            ?? avg(allHistory.compactMap(\.avgSpO2))
            ?? baselines.averageSpO2

        let daySteps = dayHistory.compactMap(\.stepCount)
        let allSteps = allHistory.compactMap(\.stepCount)
        baselines.averageDailySteps = daySteps.isEmpty
            ? (allSteps.isEmpty ? baselines.averageDailySteps : allSteps.reduce(0, +) / allSteps.count)
            : daySteps.reduce(0, +) / daySteps.count

        return baselines
    }
}
