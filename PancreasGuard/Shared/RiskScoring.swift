import Foundation

struct RiskAssessment {
    let level: RiskLevel
    let score: Double // 0.0 - 1.0
    let activeSignals: [RiskSignal]
    let temporalSignals: [TemporalSignal]
    let timestamp: Date
    let usedPersonalizedThresholds: Bool

    init(level: RiskLevel, score: Double, activeSignals: [RiskSignal], timestamp: Date, temporalSignals: [TemporalSignal] = [], usedPersonalizedThresholds: Bool = false) {
        self.level = level
        self.score = score
        self.activeSignals = activeSignals
        self.temporalSignals = temporalSignals
        self.timestamp = timestamp
        self.usedPersonalizedThresholds = usedPersonalizedThresholds
    }

    var recommendation: String {
        if !temporalSignals.isEmpty {
            let trendNames = temporalSignals.map(\.name).joined(separator: ", ")
            switch level {
            case .green:
                return "All indicators normal. Continue monitoring."
            case .yellow:
                return "Some indicators are elevated (\(trendNames)). Monitor closely and log any symptoms."
            case .orange:
                return "Multi-day warning pattern detected (\(trendNames)). Consider contacting your healthcare provider."
            case .red:
                return "Significant multi-day warning pattern (\(trendNames)). Please seek medical attention promptly."
            }
        }
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

// Validated against 3 years of real Apple Watch data (2 acute pancreatitis events).
// RED alerts fired D-3 and D-4. Tuned to reduce false positives by 88%.
// See ValidationReport.md for full methodology.
struct RiskScoringEngine {
    struct Baselines {
        var averageHeartRate: Double = 72
        var averageHRV: Double = 40
        var averageTemperature: Double = 0 // deviation from baseline
        var averageSpO2: Double = 97
        var averageDailySteps: Int = 5000
    }

    var baselines: Baselines
    var personalizedThresholds: PersonalizedThresholds?

    private var thresholds: PersonalizedThresholds {
        personalizedThresholds ?? .defaults
    }

    init(baselines: Baselines = Baselines(), personalizedThresholds: PersonalizedThresholds? = nil) {
        self.baselines = baselines
        self.personalizedThresholds = personalizedThresholds
    }

    func assess(snapshot: HealthSnapshot, recentSymptoms: [SymptomEntry], recentFood: [FoodEntry], appleHealthAlcoholDrinks: Double = 0, appleHealthDietaryFatGrams: Double = 0, recentHistory: [DailyBiometricSummary] = []) -> RiskAssessment {
        var signals: [RiskSignal] = []
        var totalWeightedScore: Double = 0
        var totalWeight: Double = 0

        // Resting Heart Rate — primary HR signal (≥100 bpm, fires on <1% of days)
        let rhrSignal = evaluateRestingHeartRate(snapshot.restingHeartRate)
        signals.append(rhrSignal)
        totalWeight += rhrSignal.weight
        if rhrSignal.isActive { totalWeightedScore += rhrSignal.weight }

        // Heart Rate — secondary, higher threshold (>110 bpm avg)
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

        // Temporal pattern analysis — multi-day trends boost risk assessment
        let temporalEngine = TemporalPatternEngine(recentSummaries: recentHistory, baselines: baselines)
        let temporalSignals = temporalEngine.detectPatterns()

        var temporalBoost: Double = 0
        for signal in temporalSignals {
            temporalBoost += signal.severity * 0.15
        }

        let adjustedScore = min(1.0, normalizedScore + temporalBoost)
        let level = riskLevel(from: adjustedScore, signals: signals, temporalSignals: temporalSignals)

        return RiskAssessment(
            level: level,
            score: adjustedScore,
            activeSignals: signals,
            timestamp: Date(),
            temporalSignals: temporalSignals,
            usedPersonalizedThresholds: personalizedThresholds != nil
        )
    }

    private func evaluateRestingHeartRate(_ restingHR: Double?) -> RiskSignal {
        guard let rhr = restingHR else {
            return RiskSignal(name: "Resting Heart Rate", description: "No data available", weight: 0.25, isActive: false)
        }
        let threshold = thresholds.restingHRAlert
        let isElevated = rhr >= threshold
        return RiskSignal(
            name: "Resting Heart Rate",
            description: isElevated ? "Elevated: \(Int(rhr)) bpm (threshold: \(Int(threshold)))" : "\(Int(rhr)) bpm — normal",
            weight: 0.25,
            isActive: isElevated
        )
    }

    private func evaluateHeartRate(_ hr: Double?) -> RiskSignal {
        guard let hr = hr else {
            return RiskSignal(name: "Heart Rate", description: "No data available", weight: 0.10, isActive: false)
        }
        let threshold = thresholds.heartRateAlert
        let isElevated = hr > threshold
        return RiskSignal(
            name: "Heart Rate",
            description: isElevated ? "Elevated: \(Int(hr)) bpm (threshold: \(Int(threshold)))" : "\(Int(hr)) bpm — normal range",
            weight: 0.10,
            isActive: isElevated
        )
    }

    private func evaluateHRV(_ hrv: Double?) -> RiskSignal {
        guard let hrv = hrv else {
            return RiskSignal(name: "HRV", description: "No data available", weight: 0.20, isActive: false)
        }
        let dropPercent = ((baselines.averageHRV - hrv) / baselines.averageHRV) * 100
        let threshold = thresholds.hrvDropPercentAlert
        let isDepressed = dropPercent > threshold
        return RiskSignal(
            name: "HRV",
            description: isDepressed ? "Dropped \(Int(dropPercent))% from baseline (threshold: \(Int(threshold))%)" : "Within normal range (\(Int(hrv)) ms)",
            weight: 0.20,
            isActive: isDepressed
        )
    }

    private func evaluateTemperature(_ temp: Double?) -> RiskSignal {
        guard let temp = temp else {
            return RiskSignal(name: "Temperature", description: "No data available", weight: 0.12, isActive: false)
        }
        let threshold = thresholds.temperatureAlert
        let isElevated = temp > threshold
        return RiskSignal(
            name: "Temperature",
            description: isElevated ? "Elevated: +\(String(format: "%.1f", temp))°C from baseline (threshold: +\(String(format: "%.1f", threshold))°)" : "Normal deviation",
            weight: 0.12,
            isActive: isElevated
        )
    }

    private func evaluateSpO2(_ spo2: Double?) -> RiskSignal {
        guard let spo2 = spo2 else {
            return RiskSignal(name: "Blood Oxygen", description: "No data available", weight: 0.12, isActive: false)
        }
        let threshold = thresholds.spo2Alert
        let isLow = spo2 < threshold
        return RiskSignal(
            name: "Blood Oxygen",
            description: isLow ? "Low: \(Int(spo2))% (threshold: \(Int(threshold))%)" : "\(Int(spo2))% — normal",
            weight: 0.12,
            isActive: isLow
        )
    }

    private func evaluateActivity(_ steps: Int?) -> RiskSignal {
        guard let steps = steps else {
            return RiskSignal(name: "Activity", description: "No data available", weight: 0.06, isActive: false)
        }
        let dropPercent = Double(baselines.averageDailySteps - steps) / Double(baselines.averageDailySteps) * 100
        let threshold = thresholds.stepDropPercentAlert
        let isReduced = dropPercent > threshold
        return RiskSignal(
            name: "Activity",
            description: isReduced ? "Activity down \(Int(dropPercent))% from baseline (threshold: \(Int(threshold))%)" : "\(steps) steps — normal",
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

    private func riskLevel(from score: Double, signals: [RiskSignal], temporalSignals: [TemporalSignal] = []) -> RiskLevel {
        let activeCount = signals.filter(\.isActive).count
        let hasSustainedPattern = temporalSignals.contains { $0.daysDetected >= 2 && $0.severity >= 0.5 }
        let hasConvergence = temporalSignals.contains { $0.name == "Multi-Signal Convergence" }

        // Multi-day sustained patterns with convergence are the strongest predictor
        if hasConvergence && hasSustainedPattern { return .red }

        if score >= 0.55 || activeCount >= 5 { return .red }
        if score >= 0.35 || activeCount >= 3 { return .orange }
        if hasSustainedPattern { return .orange }
        if score >= 0.15 || activeCount >= 1 { return .yellow }
        return .green
    }
}
