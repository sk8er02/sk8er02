import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

struct AIRiskInsight {
    let summary: String
    let confidence: String
    let shouldEscalate: Bool
    let reasoning: String
}

@Observable
final class AIRiskAnalyst {
    var latestInsight: AIRiskInsight?
    var isAnalyzing = false

    @available(iOS 27.0, watchOS 27.0, *)
    func analyzeRiskContext(
        assessment: RiskAssessment,
        temporalSignals: [TemporalSignal],
        recentHistory: [DailyBiometricSummary],
        recentSymptoms: [SymptomEntry],
        recentFood: [FoodEntry]
    ) async {
        #if canImport(FoundationModels)
        isAnalyzing = true

        let context = buildContextString(
            assessment: assessment,
            temporalSignals: temporalSignals,
            recentHistory: recentHistory,
            recentSymptoms: recentSymptoms,
            recentFood: recentFood
        )

        do {
            let session = LanguageModelSession()

            let prompt = """
            You are a health pattern analysis system for a pancreatitis patient monitoring app. \
            Analyze the following biometric and symptom data and provide a brief, actionable insight.

            IMPORTANT: You are NOT diagnosing. You are identifying patterns in wearable sensor data \
            that correlate with known pancreatitis warning signs based on published research \
            (Nature Scientific Reports 2024, NIH trial NCT04400903).

            \(context)

            Respond with ONLY a JSON object:
            {
              "summary": "1-2 sentence plain-language insight for the user",
              "confidence": "high/medium/low",
              "should_escalate": true/false,
              "reasoning": "Brief clinical reasoning about why these signals matter together"
            }

            Focus on:
            - Multi-day trends (more important than single readings)
            - Signal combinations (HR + HRV together is more meaningful than either alone)
            - Context from dietary triggers (alcohol, high fat) preceding biometric changes
            - Comparison to the user's personal baseline, not population averages
            - Whether the pattern resembles known pre-flare trajectories
            """

            let response = try await session.respond(to: prompt)
            latestInsight = parseInsight(response.content)
        } catch {
            latestInsight = nil
        }

        isAnalyzing = false
        #endif
    }

    private func buildContextString(
        assessment: RiskAssessment,
        temporalSignals: [TemporalSignal],
        recentHistory: [DailyBiometricSummary],
        recentSymptoms: [SymptomEntry],
        recentFood: [FoodEntry]
    ) -> String {
        var parts: [String] = []

        // Current snapshot
        let activeSignals = assessment.activeSignals.filter(\.isActive)
        parts.append("CURRENT RISK: \(assessment.level.rawValue) (score: \(String(format: "%.2f", assessment.score)))")
        parts.append("ACTIVE SIGNALS: \(activeSignals.map { "\($0.name): \($0.description)" }.joined(separator: "; "))")

        // Temporal patterns
        if !temporalSignals.isEmpty {
            let trends = temporalSignals.map { "\($0.name) (\($0.daysDetected) days, severity: \(String(format: "%.1f", $0.severity))): \($0.description)" }
            parts.append("MULTI-DAY TRENDS: \(trends.joined(separator: "; "))")
        }

        // Recent biometric history (last 5 days)
        let recent = recentHistory.prefix(5)
        if !recent.isEmpty {
            var historyLines: [String] = []
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd"
            for day in recent {
                var metrics: [String] = []
                if let rhr = day.restingHeartRate { metrics.append("RHR:\(Int(rhr))") }
                if let hrv = day.avgHRV { metrics.append("HRV:\(Int(hrv))") }
                if let spo2 = day.avgSpO2 { metrics.append("SpO2:\(Int(spo2))") }
                if let steps = day.stepCount { metrics.append("Steps:\(steps)") }
                if let temp = day.wristTemperature { metrics.append("Temp:+\(String(format: "%.1f", temp))°") }
                historyLines.append("\(formatter.string(from: day.date)): \(metrics.joined(separator: ", "))")
            }
            parts.append("5-DAY HISTORY:\n\(historyLines.joined(separator: "\n"))")
        }

        // Recent symptoms
        let last48hSymptoms = recentSymptoms.filter { $0.timestamp > Date().addingTimeInterval(-48 * 3600) }
        if !last48hSymptoms.isEmpty {
            let symptomDescs = last48hSymptoms.map { entry in
                var desc = "Pain \(entry.painLevel)/10 (\(entry.painLocation.rawValue))"
                if entry.hasNausea { desc += ", nausea" }
                if entry.hasVomiting { desc += ", vomiting" }
                if entry.hasFever { desc += ", fever" }
                return desc
            }
            parts.append("RECENT SYMPTOMS (48h): \(symptomDescs.joined(separator: "; "))")
        }

        // Dietary context
        let last48hFood = recentFood.filter { $0.timestamp > Date().addingTimeInterval(-48 * 3600) }
        let alcoholEntries = last48hFood.filter(\.containsAlcohol)
        let highFatEntries = last48hFood.filter(\.isHighFat)
        if !alcoholEntries.isEmpty || !highFatEntries.isEmpty {
            var dietDesc: [String] = []
            if !alcoholEntries.isEmpty {
                let totalDrinks = alcoholEntries.compactMap(\.alcoholQuantity).reduce(0, +)
                dietDesc.append("Alcohol: \(totalDrinks) drinks in 48h")
            }
            if !highFatEntries.isEmpty {
                dietDesc.append("High-fat meals: \(highFatEntries.count) in 48h")
            }
            parts.append("DIETARY TRIGGERS: \(dietDesc.joined(separator: "; "))")
        }

        return parts.joined(separator: "\n\n")
    }

    private func parseInsight(_ text: String) -> AIRiskInsight? {
        var jsonString = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if jsonString.hasPrefix("```json") { jsonString = String(jsonString.dropFirst(7)) }
        if jsonString.hasPrefix("```") { jsonString = String(jsonString.dropFirst(3)) }
        if jsonString.hasSuffix("```") { jsonString = String(jsonString.dropLast(3)) }
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return AIRiskInsight(
            summary: (json["summary"] as? String) ?? "",
            confidence: (json["confidence"] as? String) ?? "low",
            shouldEscalate: (json["should_escalate"] as? Bool) ?? false,
            reasoning: (json["reasoning"] as? String) ?? ""
        )
    }
}
