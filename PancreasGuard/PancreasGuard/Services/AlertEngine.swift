import Foundation
import UserNotifications
import SwiftData

@Observable
final class AlertEngine {
    private var scoringEngine: RiskScoringEngine
    private var lastNotificationLevel: RiskLevel = .green
    private var lastNotificationTime: Date?
    let aiAnalyst = AIRiskAnalyst()

    var currentAssessment: RiskAssessment?

    init(baselines: RiskScoringEngine.Baselines = .init()) {
        self.scoringEngine = RiskScoringEngine(baselines: baselines)
    }

    func updateBaselines(_ baselines: RiskScoringEngine.Baselines) {
        scoringEngine.baselines = baselines
    }

    func updatePersonalizedThresholds(_ thresholds: PersonalizedThresholds) {
        scoringEngine.personalizedThresholds = thresholds
    }

    func evaluate(snapshot: HealthSnapshot, symptoms: [SymptomEntry], food: [FoodEntry], appleHealthAlcoholDrinks: Double = 0, appleHealthDietaryFatGrams: Double = 0, recentHistory: [DailyBiometricSummary] = []) -> RiskAssessment {
        let assessment = scoringEngine.assess(snapshot: snapshot, recentSymptoms: symptoms, recentFood: food, appleHealthAlcoholDrinks: appleHealthAlcoholDrinks, appleHealthDietaryFatGrams: appleHealthDietaryFatGrams, recentHistory: recentHistory)
        currentAssessment = assessment

        if shouldNotify(for: assessment) {
            sendNotification(for: assessment)
            lastNotificationLevel = assessment.level
            lastNotificationTime = Date()
        }

        // Run on-device AI analysis for elevated risk
        if assessment.level >= .orange {
            Task {
                if #available(iOS 27.0, watchOS 27.0, *) {
                    await aiAnalyst.analyzeRiskContext(
                        assessment: assessment,
                        temporalSignals: assessment.temporalSignals,
                        recentHistory: recentHistory,
                        recentSymptoms: symptoms,
                        recentFood: food
                    )
                }
            }
        }

        return assessment
    }

    func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    // MARK: - Private

    private func shouldNotify(for assessment: RiskAssessment) -> Bool {
        guard assessment.level >= .yellow else { return false }

        if assessment.level > lastNotificationLevel { return true }

        if let lastTime = lastNotificationTime {
            let cooldownMinutes: TimeInterval = switch assessment.level {
            case .red: 15
            case .orange: 60
            case .yellow: 180
            case .green: .infinity
            }
            return Date().timeIntervalSince(lastTime) > cooldownMinutes * 60
        }

        return true
    }

    private func sendNotification(for assessment: RiskAssessment) {
        let content = UNMutableNotificationContent()
        let hasTrends = !assessment.temporalSignals.isEmpty

        switch assessment.level {
        case .red:
            content.title = hasTrends ? "Urgent: Multi-Day Warning Pattern" : "Urgent: Multiple Warning Signs"
            content.body = assessment.recommendation
            content.sound = .defaultCritical
        case .orange:
            content.title = hasTrends ? "Elevated Risk: Trending Pattern" : "Elevated Risk Detected"
            content.body = assessment.recommendation
            content.sound = .default
        case .yellow:
            content.title = "Monitoring Alert"
            content.body = assessment.recommendation
            content.sound = .default
        case .green:
            return
        }

        content.categoryIdentifier = "RISK_ALERT"

        let activeSignalNames = assessment.activeSignals
            .filter(\.isActive)
            .map(\.name)
            .joined(separator: ", ")
        let trendNames = assessment.temporalSignals.map(\.name).joined(separator: ", ")
        content.userInfo = [
            "signals": activeSignalNames,
            "trends": trendNames,
            "level": assessment.level.rawValue
        ]

        let request = UNNotificationRequest(
            identifier: "risk-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
