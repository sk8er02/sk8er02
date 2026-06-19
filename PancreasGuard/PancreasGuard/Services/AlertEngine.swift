import Foundation
import UserNotifications
import SwiftData

@Observable
final class AlertEngine {
    private let scoringEngine: RiskScoringEngine
    private var lastNotificationLevel: RiskLevel = .green
    private var lastNotificationTime: Date?

    var currentAssessment: RiskAssessment?

    init(baselines: RiskScoringEngine.Baselines = .init()) {
        self.scoringEngine = RiskScoringEngine(baselines: baselines)
    }

    func updateBaselines(_ baselines: RiskScoringEngine.Baselines) {
        var engine = scoringEngine
        engine.baselines = baselines
    }

    func evaluate(snapshot: HealthSnapshot, symptoms: [SymptomEntry], food: [FoodEntry]) -> RiskAssessment {
        let assessment = scoringEngine.assess(snapshot: snapshot, recentSymptoms: symptoms, recentFood: food)
        currentAssessment = assessment

        if shouldNotify(for: assessment) {
            sendNotification(for: assessment)
            lastNotificationLevel = assessment.level
            lastNotificationTime = Date()
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

        switch assessment.level {
        case .red:
            content.title = "Urgent: Multiple Warning Signs"
            content.body = assessment.recommendation
            content.sound = .defaultCritical
        case .orange:
            content.title = "Elevated Risk Detected"
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
        content.userInfo = ["signals": activeSignalNames, "level": assessment.level.rawValue]

        let request = UNNotificationRequest(
            identifier: "risk-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
