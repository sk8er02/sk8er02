import Foundation

struct RiskAssessment {
    let level: RiskLevel
    let score: Double // 0.0 - 1.0
    let activeSignals: [RiskSignal]
    let timestamp: Date

    var recommendation: String {
        switch level {
        case .green:
            return "All indicators normal. Continue monitoring."
        case .yellow:
            return "Some indicators are elevated. Monitor closely and log any symptoms."
        case .orange:
            return "Multiple warning signs detected. Consider contacting your healthcare provider."
        case .red:
            return "Significant warning pattern detected. Please seek medical attention promptly."
        }
    }
}

struct RiskSignal: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let weight: Double
    let isActive: Bool
}

// Validated against real Apple Watch data from 2 acute pancreatitis events.
// RED alerts fired D-3 and D-4 before hospitalization. See ValidationReport.md.
struct RiskScoringEngine {
    struct Baselines {
        var averageHeartRate: Double = 72
        var averageHRV: Double = 40
        var averageTemperature: Double = 0 // deviation from baseline
        var averageSpO2: Double = 97
        var averageDailySteps: Int = 5000
    }

    var baselines: Baselines

    init(baselines: Baselines = Baselines()) {
        self.baselines = baselines
    }

    func assess(snapshot: HealthSnapshot, recentSymptoms: [SymptomEntry], recentFood: [FoodEntry], appleHealthAlcoholDrinks: Double = 0, appleHealthDietaryFatGrams: Double = 0) -> RiskAssessment {
        var signals: [RiskSignal] = []
        var totalWeightedScore: Double = 0
        var totalWeight: Double = 0

        // Heart Rate — sustained tachycardia (>100 bpm)
        let hrSignal = evaluateHeartRate(snapshot.heartRate)
        signals.append(hrSignal)
        totalWeight += hrSignal.weight
        if hrSignal.isActive { totalWeightedScore += hrSignal.weight }

        // HRV — significant drop from baseline (>30%)
        let hrvSignal = evaluateHRV(snapshot.heartRateVariability)
        signals.append(hrvSignal)
        totalWeight += hrvSignal.weight
        if hrvSignal.isActive { totalWeightedScore += hrvSignal.weight }

        // Temperature — elevation from baseline
        let tempSignal = evaluateTemperature(snapshot.wristTemperature)
        signals.append(tempSignal)
        totalWeight += tempSignal.weight
        if tempSignal.isActive { totalWeightedScore += tempSignal.weight }

        // SpO2 — below 94%
        let spo2Signal = evaluateSpO2(snapshot.bloodOxygen)
        signals.append(spo2Signal)
        totalWeight += spo2Signal.weight
        if spo2Signal.isActive { totalWeightedScore += spo2Signal.weight }

        // Activity — significant drop from baseline
        let activitySignal = evaluateActivity(snapshot.stepCount)
        signals.append(activitySignal)
        totalWeight += activitySignal.weight
        if activitySignal.isActive { totalWeightedScore += activitySignal.weight }

        // User-reported pain
        let painSignal = evaluatePain(recentSymptoms)
        signals.append(painSignal)
        totalWeight += painSignal.weight
        if painSignal.isActive { totalWeightedScore += painSignal.weight }

        // GI symptoms (nausea, vomiting)
        let giSignal = evaluateGISymptoms(recentSymptoms)
        signals.append(giSignal)
        totalWeight += giSignal.weight
        if giSignal.isActive { totalWeightedScore += giSignal.weight }

        // Recent alcohol — combines in-app entries + Apple Health data from other apps
        let alcoholSignal = evaluateAlcohol(recentFood, appleHealthDrinks: appleHealthAlcoholDrinks)
        signals.append(alcoholSignal)
        totalWeight += alcoholSignal.weight
        if alcoholSignal.isActive { totalWeightedScore += alcoholSignal.weight }

        // High-fat diet — from Apple Health (MyFitnessPal, etc.) or in-app entries
        let fatSignal = evaluateDietaryFat(recentFood, appleHealthFatGrams: appleHealthDietaryFatGrams)
        signals.append(fatSignal)
        totalWeight += fatSignal.weight
        if fatSignal.isActive { totalWeightedScore += fatSignal.weight }

        let normalizedScore = totalWeight > 0 ? totalWeightedScore / totalWeight : 0
        let level = riskLevel(from: normalizedScore, signals: signals)

        return RiskAssessment(
            level: level,
            score: normalizedScore,
            activeSignals: signals,
            timestamp: Date()
        )
    }

    private func evaluateHeartRate(_ hr: Double?) -> RiskSignal {
        guard let hr = hr else {
            return RiskSignal(name: "Heart Rate", description: "No data available", weight: 0.20, isActive: false)
        }
        let isElevated = hr > 100
        return RiskSignal(
            name: "Heart Rate",
            description: isElevated ? "Elevated: \(Int(hr)) bpm (threshold: 100)" : "\(Int(hr)) bpm — normal range",
            weight: 0.20,
            isActive: isElevated
        )
    }

    private func evaluateHRV(_ hrv: Double?) -> RiskSignal {
        guard let hrv = hrv else {
            return RiskSignal(name: "HRV", description: "No data available", weight: 0.20, isActive: false)
        }
        let dropPercent = ((baselines.averageHRV - hrv) / baselines.averageHRV) * 100
        let isDepressed = dropPercent > 30
        return RiskSignal(
            name: "HRV",
            description: isDepressed ? "Dropped \(Int(dropPercent))% from baseline" : "Within normal range (\(Int(hrv)) ms)",
            weight: 0.20,
            isActive: isDepressed
        )
    }

    private func evaluateTemperature(_ temp: Double?) -> RiskSignal {
        guard let temp = temp else {
            return RiskSignal(name: "Temperature", description: "No data available", weight: 0.12, isActive: false)
        }
        let isElevated = temp > 1.0
        return RiskSignal(
            name: "Temperature",
            description: isElevated ? "Elevated: +\(String(format: "%.1f", temp))°C from baseline" : "Normal deviation",
            weight: 0.12,
            isActive: isElevated
        )
    }

    private func evaluateSpO2(_ spo2: Double?) -> RiskSignal {
        guard let spo2 = spo2 else {
            return RiskSignal(name: "Blood Oxygen", description: "No data available", weight: 0.12, isActive: false)
        }
        let isLow = spo2 < 94
        return RiskSignal(
            name: "Blood Oxygen",
            description: isLow ? "Low: \(Int(spo2))% (threshold: 94%)" : "\(Int(spo2))% — normal",
            weight: 0.12,
            isActive: isLow
        )
    }

    private func evaluateActivity(_ steps: Int?) -> RiskSignal {
        guard let steps = steps else {
            return RiskSignal(name: "Activity", description: "No data available", weight: 0.06, isActive: false)
        }
        let dropPercent = Double(baselines.averageDailySteps - steps) / Double(baselines.averageDailySteps) * 100
        let isReduced = dropPercent > 50
        return RiskSignal(
            name: "Activity",
            description: isReduced ? "Activity down \(Int(dropPercent))% from baseline" : "\(steps) steps — normal",
            weight: 0.06,
            isActive: isReduced
        )
    }

    private func evaluatePain(_ symptoms: [SymptomEntry]) -> RiskSignal {
        let recentPain = symptoms.first(where: {
            $0.timestamp > Date().addingTimeInterval(-6 * 3600) && $0.painLevel > 0
        })
        let isSignificant = (recentPain?.painLevel ?? 0) >= 5
        return RiskSignal(
            name: "Pain",
            description: isSignificant ? "Pain level \(recentPain!.painLevel)/10 reported" : "No significant pain reported",
            weight: 0.20,
            isActive: isSignificant
        )
    }

    private func evaluateGISymptoms(_ symptoms: [SymptomEntry]) -> RiskSignal {
        let recentGI = symptoms.first(where: {
            $0.timestamp > Date().addingTimeInterval(-6 * 3600) && ($0.hasNausea || $0.hasVomiting)
        })
        let isActive = recentGI != nil
        return RiskSignal(
            name: "GI Symptoms",
            description: isActive ? "Nausea/vomiting reported" : "No GI symptoms",
            weight: 0.05,
            isActive: isActive
        )
    }

    private func evaluateAlcohol(_ food: [FoodEntry], appleHealthDrinks: Double) -> RiskSignal {
        let inAppAlcohol = food.contains(where: {
            $0.timestamp > Date().addingTimeInterval(-24 * 3600) && $0.containsAlcohol
        })
        let hasAlcohol = inAppAlcohol || appleHealthDrinks > 0
        let drinkCount = appleHealthDrinks > 0 ? Int(appleHealthDrinks) : (food.first(where: { $0.containsAlcohol })?.alcoholQuantity ?? 0)
        return RiskSignal(
            name: "Alcohol",
            description: hasAlcohol ? "\(drinkCount) drink(s) in last 24h (via Apple Health or manual entry)" : "No recent alcohol",
            weight: 0.05,
            isActive: hasAlcohol
        )
    }

    private func evaluateDietaryFat(_ food: [FoodEntry], appleHealthFatGrams: Double) -> RiskSignal {
        let inAppHighFat = food.contains(where: {
            $0.timestamp > Date().addingTimeInterval(-24 * 3600) && $0.isHighFat
        })
        // >65g daily fat is considered high for pancreatitis patients
        let hasHighFat = inAppHighFat || appleHealthFatGrams > 65
        return RiskSignal(
            name: "Dietary Fat",
            description: hasHighFat
                ? (appleHealthFatGrams > 0 ? "High fat intake: \(Int(appleHealthFatGrams))g today (via Apple Health)" : "High-fat food logged")
                : "Fat intake normal",
            weight: 0.04,
            isActive: hasHighFat
        )
    }

    private func riskLevel(from score: Double, signals: [RiskSignal]) -> RiskLevel {
        let activeCount = signals.filter(\.isActive).count

        if score >= 0.55 || activeCount >= 5 { return .red }
        if score >= 0.35 || activeCount >= 3 { return .orange }
        if score >= 0.15 || activeCount >= 1 { return .yellow }
        return .green
    }
}
