import Foundation
import HealthKit
import Combine

class HealthKitManager: ObservableObject {
    let healthStore = HKHealthStore()

    @Published var isAuthorized = false
    @Published var stepCount: Int = 0
    @Published var activeEnergy: Double = 0.0
    @Published var sleepHours: Double = 0.0
    @Published var waterIntake: Double = 0.0 // in liters

    // Types to read
    private let readTypes: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        HKObjectType.quantityType(forIdentifier: .dietaryWater)!
    ]

    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, nil)
            return
        }

        // We also need share permission for water if we want to add it from the app later
        let writeTypes: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .dietaryWater)!
        ]

        healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { success, error in
            DispatchQueue.main.async {
                self.isAuthorized = success
                completion(success, error)
            }
        }
    }

    func fetchTodayHealthData(completion: (() -> Void)? = nil) {
        let group = DispatchGroup()
        fetchTodaySteps(group: group)
        fetchTodayActiveEnergy(group: group)
        fetchTodaySleep(group: group)
        fetchTodayWater(group: group)
        if let completion = completion {
            group.notify(queue: .main, execute: completion)
        }
    }

    private func fetchTodaySteps(group: DispatchGroup? = nil) {
        group?.enter()
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            group?.leave()
            return
        }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, _ in
            DispatchQueue.main.async {
                if let sum = result?.sumQuantity() {
                    self.stepCount = Int(sum.doubleValue(for: HKUnit.count()))
                }
                group?.leave()
            }
        }

        healthStore.execute(query)
    }

    private func fetchTodayActiveEnergy(group: DispatchGroup? = nil) {
        group?.enter()
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            group?.leave()
            return
        }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(
            quantityType: energyType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, _ in
            DispatchQueue.main.async {
                if let sum = result?.sumQuantity() {
                    self.activeEnergy = sum.doubleValue(for: HKUnit.kilocalorie())
                }
                group?.leave()
            }
        }

        healthStore.execute(query)
    }

    private func fetchTodayWater(group: DispatchGroup? = nil) {
        group?.enter()
        guard let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else {
            group?.leave()
            return
        }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(
            quantityType: waterType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, _ in
            DispatchQueue.main.async {
                if let sum = result?.sumQuantity() {
                    self.waterIntake = sum.doubleValue(for: HKUnit.liter())
                }
                group?.leave()
            }
        }
        healthStore.execute(query)
    }

    func fetchCumulativeSteps(from startDate: Date, to endDate: Date, completion: @escaping (Double) -> Void) {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            completion(0); return
        }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { _, result, _ in
            let value = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
            DispatchQueue.main.async { completion(value) }
        }
        healthStore.execute(query)
    }

    func fetchCumulativeCalories(from startDate: Date, to endDate: Date, completion: @escaping (Double) -> Void) {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            completion(0); return
        }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: energyType, quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { _, result, _ in
            let value = result?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0
            DispatchQueue.main.async { completion(value) }
        }
        healthStore.execute(query)
    }

    private func fetchTodaySleep(group: DispatchGroup? = nil) {
        group?.enter()
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            group?.leave()
            return
        }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        // Look back to yesterday 6 PM so overnight sleep starting before midnight is included
        let sleepWindowStart = Calendar.current.date(byAdding: .hour, value: -6, to: startOfDay) ?? startOfDay
        let predicate = HKQuery.predicateForSamples(withStart: sleepWindowStart, end: now, options: .strictStartDate)

        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { _, samples, _ in
            guard let samples = samples as? [HKCategorySample] else {
                DispatchQueue.main.async { group?.leave() }
                return
            }

            let totalSleepSeconds = samples.reduce(0.0) { result, sample in
                if sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue ||
                   sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                   sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                   sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                    return result + sample.endDate.timeIntervalSince(sample.startDate)
                }
                return result
            }

            DispatchQueue.main.async {
                self.sleepHours = totalSleepSeconds / 3600.0
                group?.leave()
            }
        }
        healthStore.execute(query)
    }
}
