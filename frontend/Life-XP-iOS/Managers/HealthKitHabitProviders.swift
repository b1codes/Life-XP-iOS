import Foundation
import HealthKit

/// Protocol for a health metric that can back a habit. New metrics (steps, sleep, heart rate,
/// mindful minutes, stand hours) plug in by adding a conformer here — no other file needs to change.
protocol HealthKitHabitProvider {
    func fetchDailyAverage(for day: Date, healthStore: HKHealthStore, completion: @escaping (Double?) -> Void)
}

struct HeadphoneExposureProvider: HealthKitHabitProvider {
    func fetchDailyAverage(for day: Date, healthStore: HKHealthStore, completion: @escaping (Double?) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .headphoneAudioExposure) else {
            completion(nil)
            return
        }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? day
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        let query = HKStatisticsQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .discreteAverage
        ) { _, result, _ in
            let value = result?.averageQuantity()?.doubleValue(for: HKUnit.decibelAWeightedSoundPressureLevel())
            DispatchQueue.main.async { completion(value) }
        }
        healthStore.execute(query)
    }
}

/// Seam that lets `UserViewModel.evaluateHealthHabits` be unit-tested without a live HKHealthStore.
/// `HealthKitManager` conforms to this in Task 3; tests provide a synchronous fake.
protocol HeadphoneExposureFetching {
    func fetchHeadphoneExposure(for day: Date, completion: @escaping (Double?) -> Void)
}

/// Pure pass/fail logic — no data (nil) counts as a pass (no exposure = success).
func evaluateHeadphoneHabit(average: Double?, maxDecibels: Double) -> Bool {
    guard let average else { return true }
    return average <= maxDecibels
}
