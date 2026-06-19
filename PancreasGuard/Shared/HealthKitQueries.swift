import Foundation
import HealthKit

struct HealthKitQueries {
    static let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    static let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    static let restingHRType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
    static let spo2Type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!
    static let wristTempType = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature)!
    static let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    static let respiratoryRateType = HKQuantityType.quantityType(forIdentifier: .respiratoryRate)!

    // Dietary types — read from other apps via Apple Health
    static let alcoholicBeveragesType = HKQuantityType.quantityType(forIdentifier: .numberOfAlcoholicBeverages)!
    static let bloodAlcoholType = HKQuantityType.quantityType(forIdentifier: .bloodAlcoholContent)!
    static let dietaryFatType = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal)!
    static let dietaryEnergyType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed)!

    static var allReadTypes: Set<HKSampleType> {
        [heartRateType, hrvType, restingHRType, spo2Type, wristTempType, stepCountType, respiratoryRateType,
         alcoholicBeveragesType, bloodAlcoholType, dietaryFatType, dietaryEnergyType]
    }

    static func latestSample(
        for type: HKQuantityType,
        store: HKHealthStore,
        completion: @escaping (Double?) -> Void
    ) {
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: type,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else {
                completion(nil)
                return
            }
            let unit = preferredUnit(for: type)
            completion(sample.quantity.doubleValue(for: unit))
        }
        store.execute(query)
    }

    static func samples(
        for type: HKQuantityType,
        from startDate: Date,
        to endDate: Date = Date(),
        store: HKHealthStore,
        completion: @escaping ([HKQuantitySample]) -> Void
    ) {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, _ in
            let quantitySamples = (samples as? [HKQuantitySample]) ?? []
            completion(quantitySamples)
        }
        store.execute(query)
    }

    static func averageOverDays(
        for type: HKQuantityType,
        days: Int,
        store: HKHealthStore,
        completion: @escaping (Double?) -> Void
    ) {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        let query = HKStatisticsQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .discreteAverage
        ) { _, statistics, _ in
            let unit = preferredUnit(for: type)
            completion(statistics?.averageQuantity()?.doubleValue(for: unit))
        }
        store.execute(query)
    }

    static func cumulativeSum(
        for type: HKQuantityType,
        since startDate: Date,
        store: HKHealthStore,
        completion: @escaping (Double?) -> Void
    ) {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        let query = HKStatisticsQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, statistics, _ in
            let unit = preferredUnit(for: type)
            completion(statistics?.sumQuantity()?.doubleValue(for: unit))
        }
        store.execute(query)
    }

    static func preferredUnit(for type: HKQuantityType) -> HKUnit {
        switch type {
        case heartRateType, restingHRType:
            return HKUnit.count().unitDivided(by: .minute())
        case hrvType:
            return .secondUnit(with: .milli)
        case spo2Type:
            return .percent()
        case wristTempType:
            return .degreeCelsius()
        case stepCountType:
            return .count()
        case respiratoryRateType:
            return HKUnit.count().unitDivided(by: .minute())
        case alcoholicBeveragesType:
            return .count()
        case bloodAlcoholType:
            return .percent()
        case dietaryFatType:
            return .gram()
        case dietaryEnergyType:
            return .kilocalorie()
        default:
            return .count()
        }
    }
}
