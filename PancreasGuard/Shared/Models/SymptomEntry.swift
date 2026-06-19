import Foundation
import SwiftData

@Model
final class SymptomEntry {
    var id: UUID
    var timestamp: Date
    var painLevel: Int // 0-10
    var painLocation: PainLocation
    var hasNausea: Bool
    var hasVomiting: Bool
    var hasFever: Bool
    var hasChills: Bool
    var hasBloating: Bool
    var stoolType: StoolType
    var notes: String

    init(
        painLevel: Int = 0,
        painLocation: PainLocation = .none,
        hasNausea: Bool = false,
        hasVomiting: Bool = false,
        hasFever: Bool = false,
        hasChills: Bool = false,
        hasBloating: Bool = false,
        stoolType: StoolType = .normal,
        notes: String = ""
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.painLevel = min(max(painLevel, 0), 10)
        self.painLocation = painLocation
        self.hasNausea = hasNausea
        self.hasVomiting = hasVomiting
        self.hasFever = hasFever
        self.hasChills = hasChills
        self.hasBloating = hasBloating
        self.stoolType = stoolType
        self.notes = notes
    }
}

enum PainLocation: String, Codable, CaseIterable {
    case none = "None"
    case epigastric = "Upper Abdomen"
    case radiatingToBack = "Radiating to Back"
    case leftSide = "Left Side"
    case rightSide = "Right Side"
    case diffuse = "Diffuse/All Over"
}

enum StoolType: String, Codable, CaseIterable {
    case normal = "Normal"
    case fatty = "Fatty/Greasy"
    case loose = "Loose/Diarrhea"
    case pale = "Pale/Clay-Colored"
    case notApplicable = "N/A"
}
