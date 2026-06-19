import Foundation
import SwiftData

@Model
final class FlareEvent {
    var id: UUID
    var startTimestamp: Date
    var endTimestamp: Date?
    var peakRiskLevel: RiskLevel
    var triggerSignals: [String]
    var resolved: Bool
    var notes: String

    init(
        peakRiskLevel: RiskLevel = .yellow,
        triggerSignals: [String] = [],
        notes: String = ""
    ) {
        self.id = UUID()
        self.startTimestamp = Date()
        self.endTimestamp = nil
        self.peakRiskLevel = peakRiskLevel
        self.triggerSignals = triggerSignals
        self.resolved = false
        self.notes = notes
    }
}

enum RiskLevel: String, Codable, CaseIterable, Comparable {
    case green = "Normal"
    case yellow = "Monitor"
    case orange = "Elevated"
    case red = "Seek Care"

    var numericValue: Int {
        switch self {
        case .green: return 0
        case .yellow: return 1
        case .orange: return 2
        case .red: return 3
        }
    }

    static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        lhs.numericValue < rhs.numericValue
    }
}
