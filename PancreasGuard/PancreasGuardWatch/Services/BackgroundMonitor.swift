import Foundation
import HealthKit

final class BackgroundMonitor {
    private let store = HKHealthStore()

    func enableBackgroundDelivery() {
        let types: [HKQuantityType] = [
            .quantityType(forIdentifier: .heartRate)!,
            .quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            .quantityType(forIdentifier: .oxygenSaturation)!
        ]

        for type in types {
            store.enableBackgroundDelivery(for: type, frequency: .immediate) { success, error in
                if let error {
                    print("Background delivery failed for \(type.identifier): \(error.localizedDescription)")
                }
            }
        }
    }

    func observeHeartRate(handler: @escaping (Double) -> Void) {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let query = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] _, completionHandler, error in
            guard error == nil else {
                completionHandler()
                return
            }
            self?.fetchLatestHeartRate { value in
                if let value { handler(value) }
                completionHandler()
            }
        }
        store.execute(query)
    }

    func observeHRV(handler: @escaping (Double) -> Void) {
        let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let query = HKObserverQuery(sampleType: hrvType, predicate: nil) { [weak self] _, completionHandler, error in
            guard error == nil else {
                completionHandler()
                return
            }
            self?.fetchLatestHRV { value in
                if let value { handler(value) }
                completionHandler()
            }
        }
        store.execute(query)
    }

    private func fetchLatestHeartRate(completion: @escaping (Double?) -> Void) {
        let type = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
            let sample = samples?.first as? HKQuantitySample
            let unit = HKUnit.count().unitDivided(by: .minute())
            completion(sample?.quantity.doubleValue(for: unit))
        }
        store.execute(query)
    }

    private func fetchLatestHRV(completion: @escaping (Double?) -> Void) {
        let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
            let sample = samples?.first as? HKQuantitySample
            completion(sample?.quantity.doubleValue(for: .secondUnit(with: .milli)))
        }
        store.execute(query)
    }
}
