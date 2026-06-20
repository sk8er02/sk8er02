import Foundation

struct TemporalSignal {
    let name: String
    let description: String
    let severity: Double // 0.0 - 1.0
    let daysDetected: Int
}

struct TemporalPatternEngine {
    let recentSummaries: [DailyBiometricSummary] // last 7 days, newest first
    let baselines: RiskScoringEngine.Baselines

    func detectPatterns() -> [TemporalSignal] {
        guard recentSummaries.count >= 3 else { return [] }
        var signals: [TemporalSignal] = []

        if let trend = detectHRTrend() { signals.append(trend) }
        if let trend = detectHRVDecline() { signals.append(trend) }
        if let trend = detectActivityCollapse() { signals.append(trend) }
        if let trend = detectSpO2Drift() { signals.append(trend) }
        if let combo = detectMultiSignalConvergence() { signals.append(combo) }

        return signals
    }

    // Resting HR rising over consecutive days — more predictive than a single spike
    private func detectHRTrend() -> TemporalSignal? {
        let rhrValues = recentSummaries.prefix(5).reversed().compactMap(\.restingHeartRate)
        guard rhrValues.count >= 3 else { return nil }

        var consecutiveRises = 0
        for i in 1..<rhrValues.count {
            if rhrValues[i] > rhrValues[i - 1] + 2 {
                consecutiveRises += 1
            } else {
                consecutiveRises = 0
            }
        }

        guard consecutiveRises >= 2 else { return nil }
        let totalRise = rhrValues.last! - rhrValues.first!
        let severity = min(1.0, totalRise / 20.0)

        return TemporalSignal(
            name: "Rising Heart Rate Trend",
            description: "Resting HR has risen \(Int(totalRise)) bpm over \(consecutiveRises + 1) days",
            severity: severity,
            daysDetected: consecutiveRises + 1
        )
    }

    // HRV declining over multiple days — mirrors what we saw D-5 through D-1 in both incidents
    private func detectHRVDecline() -> TemporalSignal? {
        let hrvValues = recentSummaries.prefix(5).reversed().compactMap(\.avgHRV)
        guard hrvValues.count >= 3, let firstHRV = hrvValues.first, firstHRV > 0 else { return nil }

        var consecutiveDrops = 0
        for i in 1..<hrvValues.count {
            if hrvValues[i] < hrvValues[i - 1] * 0.9 {
                consecutiveDrops += 1
            } else {
                consecutiveDrops = 0
            }
        }

        guard consecutiveDrops >= 2 else { return nil }
        let totalDropPercent = ((firstHRV - hrvValues.last!) / firstHRV) * 100
        let severity = min(1.0, totalDropPercent / 50.0)

        return TemporalSignal(
            name: "HRV Declining Trend",
            description: "HRV has dropped \(Int(totalDropPercent))% over \(consecutiveDrops + 1) days",
            severity: severity,
            daysDetected: consecutiveDrops + 1
        )
    }

    // Step count dropping over consecutive days — bed-bound progression
    private func detectActivityCollapse() -> TemporalSignal? {
        let stepValues = recentSummaries.prefix(5).reversed().compactMap(\.stepCount)
        guard stepValues.count >= 3, baselines.averageDailySteps > 0 else { return nil }

        let avgBaseline = Double(baselines.averageDailySteps)
        var daysBelow50 = 0
        for steps in stepValues.suffix(3) {
            if Double(steps) < avgBaseline * 0.5 {
                daysBelow50 += 1
            }
        }

        guard daysBelow50 >= 2 else { return nil }
        let latestDrop = ((avgBaseline - Double(stepValues.last!)) / avgBaseline) * 100
        let severity = min(1.0, latestDrop / 80.0)

        return TemporalSignal(
            name: "Sustained Activity Drop",
            description: "Activity below 50% of baseline for \(daysBelow50) consecutive days",
            severity: severity,
            daysDetected: daysBelow50
        )
    }

    // SpO2 drifting down over days
    private func detectSpO2Drift() -> TemporalSignal? {
        let spo2Values = recentSummaries.prefix(5).reversed().compactMap(\.avgSpO2)
        guard spo2Values.count >= 3 else { return nil }

        var consecutiveDrops = 0
        for i in 1..<spo2Values.count {
            if spo2Values[i] < spo2Values[i - 1] - 0.5 {
                consecutiveDrops += 1
            } else {
                consecutiveDrops = 0
            }
        }

        guard consecutiveDrops >= 2 else { return nil }
        let totalDrop = spo2Values.first! - spo2Values.last!
        let severity = min(1.0, totalDrop / 6.0)

        return TemporalSignal(
            name: "SpO2 Declining",
            description: "Blood oxygen dropping over \(consecutiveDrops + 1) days (−\(String(format: "%.1f", totalDrop))%)",
            severity: severity,
            daysDetected: consecutiveDrops + 1
        )
    }

    // The key insight from validation: multiple signals converging over days is the strongest predictor
    private func detectMultiSignalConvergence() -> TemporalSignal? {
        guard let today = recentSummaries.first,
              let yesterday = recentSummaries.count > 1 ? recentSummaries[1] : nil else {
            return nil
        }

        var elevatedSignals = 0
        var signalNames: [String] = []

        if let rhr = today.restingHeartRate, rhr >= 90 {
            elevatedSignals += 1
            signalNames.append("RHR")
        }
        if let hrv = today.avgHRV, baselines.averageHRV > 0, ((baselines.averageHRV - hrv) / baselines.averageHRV) > 0.25 {
            elevatedSignals += 1
            signalNames.append("HRV")
        }
        if let spo2 = today.avgSpO2, spo2 < 94 {
            elevatedSignals += 1
            signalNames.append("SpO2")
        }
        if let steps = today.stepCount, baselines.averageDailySteps > 0,
           Double(steps) < Double(baselines.averageDailySteps) * 0.5 {
            elevatedSignals += 1
            signalNames.append("Activity")
        }
        if let temp = today.wristTemperature, temp > 0.8 {
            elevatedSignals += 1
            signalNames.append("Temp")
        }

        // Check if yesterday also had multiple signals (sustained convergence)
        var yesterdaySignals = 0
        if let rhr = yesterday.restingHeartRate, rhr >= 90 { yesterdaySignals += 1 }
        if let hrv = yesterday.avgHRV, baselines.averageHRV > 0, ((baselines.averageHRV - hrv) / baselines.averageHRV) > 0.25 { yesterdaySignals += 1 }
        if let spo2 = yesterday.avgSpO2, spo2 < 94 { yesterdaySignals += 1 }

        let isSustained = yesterdaySignals >= 2 && elevatedSignals >= 2
        guard elevatedSignals >= 3 || isSustained else { return nil }

        let severity = min(1.0, Double(elevatedSignals) / 5.0 + (isSustained ? 0.2 : 0))

        return TemporalSignal(
            name: "Multi-Signal Convergence",
            description: "\(signalNames.joined(separator: " + ")) elevated\(isSustained ? " for 2+ days" : "")",
            severity: severity,
            daysDetected: isSustained ? 2 : 1
        )
    }
}
