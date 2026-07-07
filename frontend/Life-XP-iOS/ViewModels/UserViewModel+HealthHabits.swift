import Foundation

extension UserViewModel {
    /// Live "today so far" display value for a HealthKit-tracked habit's card. Display-only —
    /// does not affect XP or streaks.
    func refreshHeadphoneExposure(for habit: Habit, using fetcher: HeadphoneExposureFetching) {
        guard habit.trackingType == .headphoneAudioExposure else { return }
        fetcher.fetchHeadphoneExposure(for: Date()) { [weak self] average in
            guard let self, let average else { return }
            self.headphoneAverages[habit.id] = average
        }
    }

    /// Evaluates yesterday's average for any headphone-exposure habit not yet scored for that day,
    /// awarding/withholding XP through the existing completeHabit() streak path. Foreground-only,
    /// called from onAppear — matches resetBrokenStreaks()'s cadence, no background task.
    func evaluateHealthHabits(using fetcher: HeadphoneExposureFetching) {
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) else { return }

        for habit in habits where habit.trackingType == .headphoneAudioExposure {
            guard let maxDecibels = habit.maxDecibels else { continue }
            if let lastEval = habit.lastEvaluatedHealthDate,
               calendar.startOfDay(for: lastEval) >= calendar.startOfDay(for: yesterday) {
                continue
            }
            guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { continue }
            // Mark evaluated synchronously, before the async fetch, so a second concurrent call to
            // evaluateHealthHabits (e.g. onAppear firing again before this fetch completes) sees this
            // guard above and skips — otherwise both invocations would pass the guard and award XP
            // twice for the same day.
            habits[index].lastEvaluatedHealthDate = yesterday

            fetcher.fetchHeadphoneExposure(for: yesterday) { [weak self] average in
                guard let self, let index = self.habits.firstIndex(where: { $0.id == habit.id }) else { return }
                if evaluateHeadphoneHabit(average: average, maxDecibels: maxDecibels) {
                    self.completeHabit(self.habits[index])
                } else {
                    self.habits[index].currentStreak = 0
                    self.uploadToCloud()
                }
            }
        }
    }
}
