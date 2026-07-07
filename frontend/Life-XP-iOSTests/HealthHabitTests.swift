import Testing
import Foundation
@testable import Life_XP_iOS

@Suite("Headphone Exposure Evaluation")
struct HeadphoneExposureEvaluationTests {

    @Test func evaluate_passesWhenAverageUnderThreshold() {
        #expect(evaluateHeadphoneHabit(average: 70.0, maxDecibels: 85.0) == true)
    }

    @Test func evaluate_passesWhenAverageExactlyAtThreshold() {
        #expect(evaluateHeadphoneHabit(average: 85.0, maxDecibels: 85.0) == true)
    }

    @Test func evaluate_failsWhenAverageOverThreshold() {
        #expect(evaluateHeadphoneHabit(average: 90.0, maxDecibels: 85.0) == false)
    }

    @Test func evaluate_passesWhenNoSamples() {
        #expect(evaluateHeadphoneHabit(average: nil, maxDecibels: 85.0) == true)
    }
}

/// Synchronous fake so evaluateHealthHabits tests are deterministic — no real HealthKit call involved.
private struct FakeExposureFetcher: HeadphoneExposureFetching {
    let average: Double?
    let onFetch: (() -> Void)?

    init(average: Double?, onFetch: (() -> Void)? = nil) {
        self.average = average
        self.onFetch = onFetch
    }

    func fetchHeadphoneExposure(for day: Date, completion: @escaping (Double?) -> Void) {
        onFetch?()
        completion(average)
    }
}

/// A fetcher whose completion can be triggered manually, to simulate a second call to
/// evaluateHealthHabits arriving before the first call's async fetch has resolved.
private final class DeferredExposureFetcher: HeadphoneExposureFetching {
    private(set) var pendingCompletions: [(Double?) -> Void] = []

    func fetchHeadphoneExposure(for day: Date, completion: @escaping (Double?) -> Void) {
        pendingCompletions.append(completion)
    }

    func completeNext(with average: Double?) {
        guard !pendingCompletions.isEmpty else { return }
        pendingCompletions.removeFirst()(average)
    }
}

@Suite("Health Habit Evaluation")
struct HealthHabitEvaluationTests {

    init() {
        UserDefaults.standard.removeObject(forKey: "LifeXPUser")
        UserDefaults.standard.removeObject(forKey: "LifeXPHabits")
        UserDefaults.standard.removeObject(forKey: "LifeXPGoals")
    }

    @MainActor private func makeVM() -> UserViewModel {
        let vm = UserViewModel(skipCloudSync: true)
        vm.user = LifeXPUser()
        vm.habits = []
        return vm
    }

    private func makeHeadphoneHabit(maxDecibels: Double = 85.0, lastEvaluatedHealthDate: Date? = nil) -> Habit {
        var habit = Habit(title: "Protect Hearing", description: "", xpReward: 20, frequency: .daily)
        habit.trackingType = .headphoneAudioExposure
        habit.maxDecibels = maxDecibels
        habit.lastEvaluatedHealthDate = lastEvaluatedHealthDate
        return habit
    }

    @Test @MainActor func evaluateHealthHabits_awardsXPWhenYesterdayUnderThreshold() {
        let vm = makeVM()
        vm.habits = [makeHeadphoneHabit(maxDecibels: 85.0)]
        let fetcher = FakeExposureFetcher(average: 70.0)

        vm.evaluateHealthHabits(using: fetcher)

        #expect(vm.user.experience == 20)
        #expect(vm.habits[0].currentStreak == 1)
    }

    @Test @MainActor func evaluateHealthHabits_resetsStreakWhenYesterdayOverThreshold() {
        let vm = makeVM()
        var habit = makeHeadphoneHabit(maxDecibels: 85.0)
        habit.currentStreak = 4
        vm.habits = [habit]
        let fetcher = FakeExposureFetcher(average: 95.0)

        vm.evaluateHealthHabits(using: fetcher)

        #expect(vm.user.experience == 0)
        #expect(vm.habits[0].currentStreak == 0)
    }

    @Test @MainActor func evaluateHealthHabits_setsLastEvaluatedHealthDateToYesterday() {
        let vm = makeVM()
        vm.habits = [makeHeadphoneHabit()]
        let fetcher = FakeExposureFetcher(average: 70.0)

        vm.evaluateHealthHabits(using: fetcher)

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        #expect(Calendar.current.isDate(vm.habits[0].lastEvaluatedHealthDate!, inSameDayAs: yesterday))
    }

    @Test @MainActor func evaluateHealthHabits_skipsAlreadyEvaluatedDayWithoutFetching() {
        let vm = makeVM()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        vm.habits = [makeHeadphoneHabit(lastEvaluatedHealthDate: yesterday)]
        var fetchCount = 0
        let fetcher = FakeExposureFetcher(average: 70.0, onFetch: { fetchCount += 1 })

        vm.evaluateHealthHabits(using: fetcher)

        #expect(fetchCount == 0)
        #expect(vm.user.experience == 0)
    }

    @Test @MainActor func evaluateHealthHabits_ignoresManualHabits() {
        let vm = makeVM()
        vm.habits = [Habit(title: "Read", description: "", xpReward: 30, frequency: .daily)]
        var fetchCount = 0
        let fetcher = FakeExposureFetcher(average: 70.0, onFetch: { fetchCount += 1 })

        vm.evaluateHealthHabits(using: fetcher)

        #expect(fetchCount == 0)
        #expect(vm.user.experience == 0)
    }

    @Test @MainActor func evaluateHealthHabits_secondConcurrentCallDoesNotDoubleFetchOrAward() {
        let vm = makeVM()
        vm.habits = [makeHeadphoneHabit(maxDecibels: 85.0)]
        let fetcher = DeferredExposureFetcher()

        vm.evaluateHealthHabits(using: fetcher)   // fires a fetch, does not complete yet
        vm.evaluateHealthHabits(using: fetcher)   // should skip: lastEvaluatedHealthDate already set

        #expect(fetcher.pendingCompletions.count == 1)   // only one fetch was ever started

        fetcher.completeNext(with: 70.0)   // resolve the first (and only) fetch

        #expect(vm.user.experience == 20)   // awarded exactly once
    }
}
