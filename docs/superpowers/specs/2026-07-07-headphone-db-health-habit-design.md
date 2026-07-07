# Headphone dB Habit & HealthKit Habit Provider — Design Spec
**Date:** 2026-07-07
**ClickUp Task:** 86bahpymf

---

## Overview

Add a "Headphone Audio Exposure" habit type: users set a max daily average dB threshold, the app reads `HKQuantityTypeIdentifier.headphoneAudioExposure` from HealthKit, displays a live running average on the habit card, and evaluates pass/fail (awarding/withholding XP) once the day is over. Alongside this, introduce a `HealthKitHabitProvider` protocol so future health-metric habits (steps, sleep, heart rate, mindful minutes, stand hours) can plug in with minimal boilerplate.

**Scope:** Headphone dB is implemented fully. The other five metrics listed in the ticket are **not** implemented — only the protocol seam is built, proven by this one conformer. The ticket's checklist for those items is left unchecked; building them out is future work.

---

## Architecture

Follows the existing MVVM pattern, mirroring how `Goal`/`GoalTrackingType` already handles HealthKit-backed tracking:
- `Habit` gains a tracking type + threshold, parallel to `Goal`/`GoalTrackingType`
- New `HealthKitHabitProvider` protocol + `HeadphoneExposureProvider` conformer
- `HealthKitManager` gains a query method + cache for the new metric
- `UserViewModel` gains a foreground evaluation pass, parallel to `resetBrokenStreaks()`
- `AddHabitView`/`HabitListView` gain tracking-type UI

---

## Section 1: Data Model (`Models.swift`)

```swift
enum HabitTrackingType: String, Codable, CaseIterable {
    case manual
    case headphoneAudioExposure

    var displayName: String {
        switch self {
        case .manual: return "Manual"
        case .headphoneAudioExposure: return "Headphone Audio Exposure (HealthKit)"
        }
    }
}
```

`Habit` gains:
```swift
var trackingType: HabitTrackingType = .manual
var maxDecibels: Double?        // threshold, only set when trackingType == .headphoneAudioExposure
var lastEvaluatedHealthDate: Date?  // last calendar day already scored, prevents double-evaluation
```

**Codable safety (critical):** Swift's synthesized `Decodable` throws `keyNotFound` for a missing key even when the property declares a default value — only `Optional` properties fall back to `nil` on a missing key. Existing users have `Habit` JSON persisted in `UserDefaults` (`"LifeXPHabits"`) with none of these three keys. `loadHabits()` decodes with `try?` and falls back to reseeding the 3 default habits on **any** decode failure — so without a fix, every existing user's habits would silently be wiped on first launch after this update.

Fix: custom `init(from decoder:)` for `Habit` using `decodeIfPresent` for the three new fields (defaulting `trackingType` to `.manual` and the other two to `nil` when absent), keeping all pre-existing fields on synthesized behavior. A matching `encode(to:)` is required once a custom initializer exists.

`isCompletedToday` is unchanged — it continues to reflect `lastCompletedDate`, which the health-evaluation path also sets on a pass (see Section 4), so streak/completion UI works unmodified for HealthKit-tracked habits.

---

## Section 2: `HealthKitHabitProvider` Protocol (new file `HealthKitHabitProviders.swift`)

```swift
protocol HealthKitHabitProvider {
    /// Fetches the aggregate value for the given calendar day. nil = no samples / unavailable.
    func fetchDailyAverage(for day: Date, healthStore: HKHealthStore, completion: @escaping (Double?) -> Void)
}

struct HeadphoneExposureProvider: HealthKitHabitProvider {
    func fetchDailyAverage(for day: Date, healthStore: HKHealthStore, completion: @escaping (Double?) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .headphoneAudioExposure) else {
            completion(nil); return
        }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? day
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate,
                                      options: .discreteAverage) { _, result, _ in
            let value = result?.averageQuantity()?.doubleValue(for: HKUnit.decibelAWeightedSoundPressureLevel())
            DispatchQueue.main.async { completion(value) }
        }
        healthStore.execute(query)
    }
}
```

Uses `.discreteAverage` / `averageQuantity()`, **not** `.cumulativeSum` like the existing steps/energy/water methods — summing dB samples is not meaningful; the ticket specifies a daily average.

**Testability (explicit AC):** pass/fail evaluation is a separate pure function, independent of HealthKit:
```swift
func evaluateHeadphoneHabit(average: Double?, maxDecibels: Double) -> Bool {
    guard let average else { return true }  // no samples today = no exposure = pass
    return average <= maxDecibels
}
```
This is unit-testable with plain `Double?` inputs — no `HKHealthStore` mocking required. The "no data" case is treated as a pass, stated explicitly since it's the one ambiguous case in the AC.

---

## Section 3: `HealthKitManager` Changes

- Add `.headphoneAudioExposure` to `readTypes` (existing `requestAuthorization` call picks it up automatically; users who already granted authorization will see a new permission prompt for this type on next request, which is expected HealthKit behavior when the read set changes).
- New method:
  ```swift
  func fetchHeadphoneExposure(for day: Date, completion: @escaping (Double?) -> Void)
  ```
  Delegates to `HeadphoneExposureProvider`, checks an in-memory cache first.
- Cache: `private var dailyAverageCache: [String: (day: Date, value: Double?)] = [:]` keyed by `habit.id.uuidString`, invalidated when `day` differs from the cached entry's day (calendar-day comparison via `Calendar.current.isDate(_:inSameDayAs:)`). Avoids re-querying HealthKit every time the habit card view refreshes within the same day.
- Existing steps/energy/sleep/water methods are **untouched** — no refactor, to avoid regressing `Goal` HealthKit tracking (out of scope for this ticket).

---

## Section 4: `UserViewModel` Changes

### Live display (today, in progress)
`HabitListView` calls a new `viewModel.refreshHeadphoneExposure(for: habit, using: healthKitManager)` on appear (mirroring `refreshHealthKitGoals`), which fetches today's running average via `fetchHeadphoneExposure(for: Date())` and publishes it into a `@Published var headphoneAverages: [UUID: Double] = [:]` dictionary for the card to read. This is display-only — it does not affect XP/streak.

### End-of-day evaluation
New method, called at the same point `resetBrokenStreaks()` is currently called (app launch / becoming active):
```swift
func evaluateHealthHabits(using healthKitManager: HealthKitManager) {
    let calendar = Calendar.current
    for habit in habits where habit.trackingType == .headphoneAudioExposure {
        guard let maxDecibels = habit.maxDecibels else { continue }
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) else { continue }
        // Skip if already evaluated for this calendar day, or no full day has elapsed yet
        if let lastEval = habit.lastEvaluatedHealthDate, calendar.isDate(lastEval, inSameDayAs: yesterday) {
            continue
        }
        healthKitManager.fetchHeadphoneExposure(for: yesterday) { [weak self] average in
            guard let self, let index = self.habits.firstIndex(where: { $0.id == habit.id }) else { return }
            self.habits[index].lastEvaluatedHealthDate = yesterday
            if evaluateHeadphoneHabit(average: average, maxDecibels: maxDecibels) {
                self.completeHabit(self.habits[index])   // existing streak+XP path
            } else {
                self.habits[index].currentStreak = 0     // fail: no XP, streak resets
            }
            self.saveHabits()
            self.uploadToCloud()
        }
    }
}
```
This reuses `completeHabit`'s existing streak/XP/gold/stat-boost logic on a pass, so HealthKit-driven habits earn rewards through the same path as manual ones — no duplicate reward logic. Evaluation is once-per-day and idempotent via `lastEvaluatedHealthDate`, matching the ticket's "prefer foreground-fetch on app launch" guidance (no background task).

**Creation-day edge case:** without a guard, a freshly-created habit would have `lastEvaluatedHealthDate == nil` and the next launch would evaluate "yesterday" — a day before the habit existed — as a free pass (no samples = pass per Section 2). To avoid an unearned XP grant on habit creation, `addHabit` initializes `lastEvaluatedHealthDate = calendar.startOfDay(for: Date())` (today) when `trackingType == .headphoneAudioExposure`, so the first real evaluation happens the day *after* creation, once a full day of data exists.

---

## Section 5: Views

### `AddHabitView.swift`
- New `Picker("Tracking", selection: $trackingType)` over `HabitTrackingType.allCases`.
- When `.headphoneAudioExposure` is selected: reveal a `Stepper` or numeric field for `maxDecibels` (default 85 dB, a commonly cited hearing-safety threshold), and call `healthKitManager.requestAuthorization` on selection so the permission prompt appears at the moment it's relevant, not buried at first app launch.
- `viewModel.addHabit(...)` gains `trackingType:` and `maxDecibels:` parameters.

### `HabitListView.swift` / `HabitRowView`
- For `habit.trackingType == .headphoneAudioExposure`: replace the tap-to-complete circle with a non-interactive live readout, e.g. `"62 dB avg today"` sourced from `viewModel.headphoneAverages[habit.id]`, plus the existing streak/XP labels unchanged. No manual completion affordance — these are HealthKit-driven only.
- Graceful degradation: if `HKHealthStore.isHealthDataAvailable()` is false or authorization was denied, show a small inline notice ("HealthKit unavailable — this habit won't update automatically") instead of a blank/misleading state.

### `ContentView.swift`
- Add `viewModel.evaluateHealthHabits(using: healthKitManager)` alongside the existing `healthKitManager.fetchTodayHealthData()` call on appear.

---

## Section 6: CloudKit Sync (`CloudKitManager`)

`saveHabits`/`fetchHabits` manually serialize each `Habit` field to/from `CKRecord` — the new fields must be added explicitly or they'll silently reset to defaults on every cloud round-trip:
- `record["trackingType"] = habit.trackingType.rawValue`
- `record["maxDecibels"]` (optional, only set if non-nil)
- `record["lastEvaluatedHealthDate"]` (optional, only set if non-nil)

And the corresponding optional reads in `fetchHabits`'s reconstruction closure, defaulting to `.manual`/`nil` if absent (same safety concern as Section 1, for records written before this change).

---

## Section 7: Testing

- Pure-function unit tests for `evaluateHeadphoneHabit(average:maxDecibels:)`: under threshold, over threshold, exactly at threshold, `nil` (no data) → pass.
- `Habit` decode test: decode a pre-migration JSON blob (no `trackingType`/`maxDecibels`/`lastEvaluatedHealthDate` keys) and assert it succeeds with `.manual`/`nil`/`nil` rather than throwing.
- `evaluateHealthHabits` idempotency: verify a habit already evaluated for a given day is skipped on a second call (no double XP award).

---

## Out of Scope (Future Work)
- Steps, sleep, heart rate, mindful minutes, stand hours habit types (protocol seam only)
- Background (`BGAppRefreshTask`) evaluation — foreground-only per ticket guidance
- Historical dB trend charts / graphs
