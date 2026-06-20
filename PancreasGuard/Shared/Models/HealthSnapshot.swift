import Foundation
import SwiftData

@Model
final class HealthSnapshot {
    var id: UUID
    var timestamp: Date
    var heartRate: Double? // bpm
    var heartRateVariability: Double? // ms (SDNN)
    var wristTemperature: Double? // °C deviation from baseline
    var bloodOxygen: Double? // percentage 0-100
    var stepCount: Int?
    var restingHeartRate: Double?
    var respiratoryRate: Double?

    init(
        heartRate: Double? = nil,
        heartRateVariability: Double? = nil,
        wristTemperature: Double? = nil,
        bloodOxygen: Double? = nil,
        stepCount: Int? = nil,
        restingHeartRate: Double? = nil,
        respiratoryRate: Double? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.heartRate = heartRate
        self.heartRateVariability = heartRateVariability
        self.wristTemperature = wristTemperature
        self.bloodOxygen = bloodOxygen
        self.stepCount = stepCount
        self.restingHeartRate = restingHeartRate
        self.respiratoryRate = respiratoryRate
    }
}
