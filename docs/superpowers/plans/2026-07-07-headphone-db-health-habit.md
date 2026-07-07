# Headphone dB Health Habit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a HealthKit-backed "Headphone Audio Exposure" habit type — users set a max daily average dB threshold, the app reads `HKQuantityTypeIdentifier.headphoneAudioExposure`, shows a live running average on the habit card, and auto-evaluates pass/fail once the day is over — plus a `HealthKitHabitProvider` protocol seam other health metrics can plug into later.

**Architecture:** Mirrors the existing `Goal`/`GoalTrackingType` HealthKit pattern already in this codebase. New pure-function evaluation logic and a fetch-orchestration protocol (`HeadphoneExposureFetching`) keep the aggregation/evaluation logic unit-testable without a live `HKHealthStore`. Evaluation runs foreground-only, hooked into the same `onAppear`/authorization flow that already drives `refreshHealthKitGoals`.

**Tech Stack:** Swift, SwiftUI, HealthKit, Swift Testing (`@Test`/`#expect`/`@Suite`, not XCTest), CloudKit.

**Spec:** `docs/superpowers/specs/2026-07-07-headphone-db-health-habit-design.md`

## Global Constraints

- Do **not** implement or stub the other five health metrics from the ticket (steps/sleep/heart rate/mindful minutes/stand hours) — only the protocol seam, proven by the one `HeadphoneExposureProvider` conformer.
- Do **not** refactor the existing `HealthKitManager` steps/energy/sleep/water methods — out of scope, risks regressing `Goal` tracking.
- Use `HKStatisticsQuery` with `.discreteAverage` / `averageQuantity()` for headphone exposure — **not** `.cumulativeSum` (summing dB is meaningless).
- No-data day (0 samples) → evaluates as a **pass** (no exposure = success).
- All new `Habit` fields must be added via `decodeIfPresent` in a custom `init(from:)` — a synthesized `Decodable` throws `keyNotFound` for a missing key even when a Swift default value is declared, which would silently wipe existing users' persisted habits via the `try?` in `loadHabits()`.
- Test framework in this repo is **Swift Testing**, not XCTest: `import Testing`, `@Suite("Name") struct X { @Test func foo() { #expect(...) } }`, `@Test @MainActor func bar()` for view-model tests.
- Build/test command (verified working):
  ```bash
  xcodebuild test -project /Users/brandonlamer-connolly/code/Life-XP-iOS/frontend/Life-XP-iOS.xcodeproj \
    -scheme Life-XP-iOS \
    -destination 'platform=iOS Simulator,id=B346B89B-C586-442A-A238-7ABE19CB38DE'
  ```
  ```bash
  xcodebuild -project /Users/brandonlamer-connolly/code/Life-XP-iOS/frontend/Life-XP-iOS.xcodeproj \
    -scheme Life-XP-iOS \
    -destination 'platform=iOS Simulator,id=B346B89B-C586-442A-A238-7ABE19CB38DE' \
    build
  ```

---

### Task 1: `Habit` model — tracking type, dB threshold, and safe migration

**Files:**
- Modify: `frontend/Life-XP-iOS/Models/Models.swift` (the `Habit` struct, currently lines 68–83)
- Test: `frontend/Life-XP-iOSTests/LifeXPiOSTests.swift` (append to the existing `@Suite("Habit")` `HabitTests` struct, currently lines 79–104)

**Interfaces:**
- Produces: `enum HabitTrackingType: String, Codable, CaseIterable { case manual, headphoneAudioExposure }` with `var displayName: String`
- Produces: `Habit` gains `var trackingType: HabitTrackingType = .manual`, `var maxDecibels: Double?`, `var lastEvaluatedHealthDate: Date?`
- Produces: `Habit.init(title:description:xpReward:frequency:category:)` unchanged in signature (all existing call sites — `CloudKitManager.fetchHabits`, `UserViewModel.loadHabits`/`addHabit`, `PreviewData.swift`, all test files — keep compiling unchanged)

- [ ] **Step 1: Write the failing test for safe decode of pre-migration JSON**

Add this test inside the existing `@Suite("Habit")` `struct HabitTests` block in `frontend/Life-XP-iOSTests/LifeXPiOSTests.swift` (right after `isCompletedToday_falseWhenCompletedLastWeek`):

```swift
    @Test func decode_missingHealthFields_defaultsToManualWithoutThrowing() throws {
        // Simulates a Habit persisted by a build before trackingType/maxDecibels/lastEvaluatedHealthDate existed.
        let legacyJSON = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "title": "Drink Water",
            "description": "Stay hydrated",
            "xpReward": 10,
            "frequency": "daily",
            "category": "health",
            "currentStreak": 3,
            "longestStreak": 5
        }
        """.data(using: .utf8)!

        let habit = try JSONDecoder().decode(Habit.self, from: legacyJSON)
        #expect(habit.title == "Drink Water")
        #expect(habit.currentStreak == 3)
        #expect(habit.trackingType == .manual)
        #expect(habit.maxDecibels == nil)
        #expect(habit.lastEvaluatedHealthDate == nil)
    }

    @Test func decode_thenEncode_roundTripsHealthFields() throws {
        var habit = Habit(title: "Headphone Safety", description: "", xpReward: 20, frequency: .daily)
        habit.trackingType = .headphoneAudioExposure
        habit.maxDecibels = 85.0
        habit.lastEvaluatedHealthDate = Date()

        let data = try JSONEncoder().encode(habit)
        let decoded = try JSONDecoder().decode(Habit.self, from: data)

        #expect(decoded.trackingType == .headphoneAudioExposure)
        #expect(decoded.maxDecibels == 85.0)
        #expect(decoded.lastEvaluatedHealthDate != nil)
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:
```bash
xcodebuild test -project /Users/brandonlamer-connolly/code/Life-XP-iOS/frontend/Life-XP-iOS.xcodeproj \
  -scheme Life-XP-iOS \
  -destination 'platform=iOS Simulator,id=B346B89B-C586-442A-A238-7ABE19CB38DE' \
  -only-testing:Life-XP-iOSTests/HabitTests
```
Expected: build error or test failure — `HabitTrackingType`, `trackingType`, `maxDecibels`, `lastEvaluatedHealthDate` don't exist yet on `Habit`.

- [ ] **Step 3: Replace the `Habit` struct in `Models.swift`**

Replace the current `Habit` struct (lines 68–83) with:

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

struct Habit: Identifiable, Codable {
    var id = UUID()
    var title: String
    var description: String
    var xpReward: Int
    var frequency: HabitFrequency
    var category: HabitCategory = .physical
    var lastCompletedDate: Date?
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var reminderTime: Date?
    var trackingType: HabitTrackingType = .manual
    var maxDecibels: Double?
    var lastEvaluatedHealthDate: Date?

    var isCompletedToday: Bool {
        guard let lastCompletedDate = lastCompletedDate else { return false }
        return Calendar.current.isDateInToday(lastCompletedDate)
    }

    init(title: String, description: String, xpReward: Int, frequency: HabitFrequency,
         category: HabitCategory = .physical) {
        self.title = title
        self.description = description
        self.xpReward = xpReward
        self.frequency = frequency
        self.category = category
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, description, xpReward, frequency, category
        case lastCompletedDate, currentStreak, longestStreak, reminderTime
        case trackingType, maxDecibels, lastEvaluatedHealthDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        xpReward = try container.decode(Int.self, forKey: .xpReward)
        frequency = try container.decode(HabitFrequency.self, forKey: .frequency)
        category = try container.decodeIfPresent(HabitCategory.self, forKey: .category) ?? .physical
        lastCompletedDate = try container.decodeIfPresent(Date.self, forKey: .lastCompletedDate)
        currentStreak = try container.decodeIfPresent(Int.self, forKey: .currentStreak) ?? 0
        longestStreak = try container.decodeIfPresent(Int.self, forKey: .longestStreak) ?? 0
        reminderTime = try container.decodeIfPresent(Date.self, forKey: .reminderTime)
        trackingType = try container.decodeIfPresent(HabitTrackingType.self, forKey: .trackingType) ?? .manual
        maxDecibels = try container.decodeIfPresent(Double.self, forKey: .maxDecibels)
        lastEvaluatedHealthDate = try container.decodeIfPresent(Date.self, forKey: .lastEvaluatedHealthDate)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(xpReward, forKey: .xpReward)
        try container.encode(frequency, forKey: .frequency)
        try container.encode(category, forKey: .category)
        try container.encodeIfPresent(lastCompletedDate, forKey: .lastCompletedDate)
        try container.encode(currentStreak, forKey: .currentStreak)
        try container.encode(longestStreak, forKey: .longestStreak)
        try container.encodeIfPresent(reminderTime, forKey: .reminderTime)
        try container.encode(trackingType, forKey: .trackingType)
        try container.encodeIfPresent(maxDecibels, forKey: .maxDecibels)
        try container.encodeIfPresent(lastEvaluatedHealthDate, forKey: .lastEvaluatedHealthDate)
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run the same command as Step 2. Expected: both new tests pass, and all pre-existing tests in `HabitTests` still pass (they don't reference the new fields, so the defaults must hold).

- [ ] **Step 5: Run the full test suite to check for regressions**

Run:
```bash
xcodebuild test -project /Users/brandonlamer-connolly/code/Life-XP-iOS/frontend/Life-XP-iOS.xcodeproj \
  -scheme Life-XP-iOS \
  -destination 'platform=iOS Simulator,id=B346B89B-C586-442A-A238-7ABE19CB38DE'
```
Expected: PASS — this confirms `Habit(title:description:xpReward:frequency:category:)` still satisfies every existing call site (tests, `CloudKitManager.fetchHabits`, `UserViewModel.loadHabits`, `PreviewData.swift`).

- [ ] **Step 6: Commit**

```bash
git add frontend/Life-XP-iOS/Models/Models.swift frontend/Life-XP-iOSTests/LifeXPiOSTests.swift
git commit -m "Add HabitTrackingType and dB threshold fields to Habit model

Custom Codable conformance uses decodeIfPresent for the new fields so
existing persisted habits (missing these keys) don't fail to decode."
```

---

### Task 2: `HealthKitHabitProvider` protocol, `HeadphoneExposureProvider`, and pure evaluation logic

**Files:**
- Create: `frontend/Life-XP-iOS/Managers/HealthKitHabitProviders.swift`
- Test: Create `frontend/Life-XP-iOSTests/HealthHabitTests.swift`

**Interfaces:**
- Produces: `protocol HealthKitHabitProvider { func fetchDailyAverage(for day: Date, healthStore: HKHealthStore, completion: @escaping (Double?) -> Void) }`
- Produces: `struct HeadphoneExposureProvider: HealthKitHabitProvider`
- Produces: `protocol HeadphoneExposureFetching { func fetchHeadphoneExposure(for day: Date, completion: @escaping (Double?) -> Void) }` — the fetch-orchestration seam `HealthKitManager` will conform to in Task 3, and that tests fake in Task 4.
- Produces: `func evaluateHeadphoneHabit(average: Double?, maxDecibels: Double) -> Bool` — pure, no HealthKit dependency.
- Consumes: nothing from other tasks (this file only depends on `Foundation`/`HealthKit`, which are already codebase dependencies).

- [ ] **Step 1: Write the failing tests for the pure evaluation function**

Create `frontend/Life-XP-iOSTests/HealthHabitTests.swift`:

```swift
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run:
```bash
xcodebuild test -project /Users/brandonlamer-connolly/code/Life-XP-iOS/frontend/Life-XP-iOS.xcodeproj \
  -scheme Life-XP-iOS \
  -destination 'platform=iOS Simulator,id=B346B89B-C586-442A-A238-7ABE19CB38DE' \
  -only-testing:Life-XP-iOSTests/HeadphoneExposureEvaluationTests
```
Expected: build failure — `evaluateHeadphoneHabit` is undefined. (Note: this new test file must also be added to the `Life-XP-iOSTests` target's "Target Membership" in Xcode if not picked up automatically — verify in the project navigator if the build fails with "file not found in target" rather than "symbol undefined".)

- [ ] **Step 3: Create `HealthKitHabitProviders.swift`**

```swift
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run the same command as Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add frontend/Life-XP-iOS/Managers/HealthKitHabitProviders.swift frontend/Life-XP-iOSTests/HealthHabitTests.swift
git commit -m "Add HealthKitHabitProvider protocol seam and headphone dB evaluation logic

Pure evaluateHeadphoneHabit() and the HeadphoneExposureFetching seam
keep pass/fail logic unit-testable without a live HKHealthStore."
```

---

### Task 3: `HealthKitManager` — headphone exposure query, caching, authorization

**Files:**
- Modify: `frontend/Life-XP-iOS/Managers/HealthKitManager.swift`

**Interfaces:**
- Consumes: `HeadphoneExposureProvider` and `HeadphoneExposureFetching` from Task 2.
- Produces: `HealthKitManager.fetchHeadphoneExposure(for day: Date, completion: @escaping (Double?) -> Void)`, and `HealthKitManager: HeadphoneExposureFetching` conformance, for Task 4 to consume.

- [ ] **Step 1: Add the new type to `readTypes` and cache storage**

In `frontend/Life-XP-iOS/Managers/HealthKitManager.swift`, change the `readTypes` set (lines 14–21):

```swift
    private let readTypes: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        HKObjectType.quantityType(forIdentifier: .dietaryWater)!,
        HKObjectType.quantityType(forIdentifier: .headphoneAudioExposure)!
    ]

    private let headphoneExposureProvider = HeadphoneExposureProvider()
    private var headphoneExposureCache: (day: Date, value: Double?)?
```

(Add the `headphoneExposureProvider`/`headphoneExposureCache` properties directly below `readTypes`, still inside the `HealthKitManager` class body.)

- [ ] **Step 2: Add `fetchHeadphoneExposure` with per-day caching, and the `HeadphoneExposureFetching` conformance**

Append to the end of `HealthKitManager.swift`, before the closing brace of the class (after `fetchTodaySleep`, i.e. after line 199 in the original file):

```swift

    /// Not habit-scoped — a single cached (day, value) pair is enough since every headphone habit
    /// reads the same underlying HealthKit samples for a given day. Avoids re-querying HealthKit
    /// on every card refresh within the same calendar day.
    func fetchHeadphoneExposure(for day: Date, completion: @escaping (Double?) -> Void) {
        if let cached = headphoneExposureCache, Calendar.current.isDate(cached.day, inSameDayAs: day) {
            completion(cached.value)
            return
        }
        headphoneExposureProvider.fetchDailyAverage(for: day, healthStore: healthStore) { [weak self] value in
            self?.headphoneExposureCache = (day: day, value: value)
            completion(value)
        }
    }
}

extension HealthKitManager: HeadphoneExposureFetching {}
```

★ Insight ─────────────────────────────────────
The spec originally suggested caching per-habit (keyed by `habit.id`), but `fetchHeadphoneExposure` only receives a `Date`, not a `Habit` — it has no habit identity to key on, and multiple headphone habits (unlikely, but not prevented by the model) would all share the same underlying HealthKit samples for a given day anyway. Caching by day alone is simpler and correct: it still eliminates the redundant HealthKit queries the ticket's "cache daily aggregates" requirement is about, without inventing a habit-awareness this manager doesn't otherwise have.
─────────────────────────────────────────────────

- [ ] **Step 3: Build to verify it compiles**

Run:
```bash
xcodebuild -project /Users/brandonlamer-connolly/code/Life-XP-iOS/frontend/Life-XP-iOS.xcodeproj \
  -scheme Life-XP-iOS \
  -destination 'platform=iOS Simulator,id=B346B89B-C586-442A-A238-7ABE19CB38DE' \
  build
```
Expected: BUILD SUCCEEDED. (No unit test for this step — it's a thin HealthKit query wrapper; correctness of the query itself is covered indirectly by the pure-function tests in Task 2, and this file has no existing test coverage to extend.)

- [ ] **Step 4: Commit**

```bash
git add frontend/Life-XP-iOS/Managers/HealthKitManager.swift
git commit -m "Add headphone audio exposure query to HealthKitManager

Reads HKQuantityTypeIdentifier.headphoneAudioExposure via
HeadphoneExposureProvider, cached per calendar day."
```

---

### Task 4: `UserViewModel` — habit creation, live readout, and end-of-day evaluation

**Files:**
- Modify: `frontend/Life-XP-iOS/ViewModels/UserViewModel.swift` (`addHabit`, and the `@Published` properties block)
- Create: `frontend/Life-XP-iOS/ViewModels/UserViewModel+HealthHabits.swift`
- Test: Append to `frontend/Life-XP-iOSTests/HealthHabitTests.swift`

**Interfaces:**
- Consumes: `Habit.trackingType`/`maxDecibels`/`lastEvaluatedHealthDate` (Task 1), `HeadphoneExposureFetching`/`evaluateHeadphoneHabit` (Task 2), `HealthKitManager.fetchHeadphoneExposure` (Task 3).
- Produces: `@Published var headphoneAverages: [UUID: Double]` on `UserViewModel`, read by `HabitListView` in Task 8.
- Produces: `UserViewModel.addHabit(title:description:experiencePoints:category:trackingType:maxDecibels:reminderTime:)` — new trailing params with defaults, so `AddHabitView`'s existing call and all test call sites keep compiling unchanged until Task 7 updates `AddHabitView`.
- Produces: `UserViewModel.refreshHeadphoneExposure(for:using:)` and `UserViewModel.evaluateHealthHabits(using:)`, called from views in Task 6.

- [ ] **Step 1: Write the failing tests**

Append to `frontend/Life-XP-iOSTests/HealthHabitTests.swift` (after the `HeadphoneExposureEvaluationTests` suite):

```swift

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
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:
```bash
xcodebuild test -project /Users/brandonlamer-connolly/code/Life-XP-iOS/frontend/Life-XP-iOS.xcodeproj \
  -scheme Life-XP-iOS \
  -destination 'platform=iOS Simulator,id=B346B89B-C586-442A-A238-7ABE19CB38DE' \
  -only-testing:Life-XP-iOSTests/HealthHabitEvaluationTests
```
Expected: build failure — `evaluateHealthHabits(using:)` doesn't exist yet.

- [ ] **Step 3: Add `headphoneAverages` published state and update `addHabit`**

In `frontend/Life-XP-iOS/ViewModels/UserViewModel.swift`, add a new `@Published` property next to the other habit-related state (near line 7, right after `@Published var habits`):

```swift
    @Published var headphoneAverages: [UUID: Double] = [:]
```

Then replace `addHabit` (currently lines 282–291):

```swift
    func addHabit(title: String, description: String, experiencePoints: Int,
                  category: HabitCategory = .physical, trackingType: HabitTrackingType = .manual,
                  maxDecibels: Double? = nil, reminderTime: Date? = nil) {
        var newHabit = Habit(title: title, description: description,
                             xpReward: experiencePoints, frequency: .daily, category: category)
        newHabit.trackingType = trackingType
        newHabit.maxDecibels = maxDecibels
        // A freshly-created HealthKit habit has no data for "yesterday" (the habit didn't exist).
        // Mark today as already evaluated so the first real evaluation happens tomorrow, once a
        // full day of samples exists — otherwise the no-data default (pass) would award a free XP.
        if trackingType != .manual {
            newHabit.lastEvaluatedHealthDate = Calendar.current.startOfDay(for: Date())
        }
        newHabit.reminderTime = reminderTime
        habits.append(newHabit)
        if reminderTime != nil { scheduleReminder(for: newHabit) }
        saveHabits()
        uploadToCloud()
    }
```

- [ ] **Step 4: Create `UserViewModel+HealthHabits.swift`**

```swift
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
            if let lastEval = habit.lastEvaluatedHealthDate, calendar.isDate(lastEval, inSameDayAs: yesterday) {
                continue
            }

            fetcher.fetchHeadphoneExposure(for: yesterday) { [weak self] average in
                guard let self, let index = self.habits.firstIndex(where: { $0.id == habit.id }) else { return }
                self.habits[index].lastEvaluatedHealthDate = yesterday
                if evaluateHeadphoneHabit(average: average, maxDecibels: maxDecibels) {
                    self.completeHabit(self.habits[index])
                } else {
                    self.habits[index].currentStreak = 0
                }
                self.saveHabits()
                self.uploadToCloud()
            }
        }
    }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run the same command as Step 2. Expected: PASS.

- [ ] **Step 6: Run the full test suite to check for regressions**

Run:
```bash
xcodebuild test -project /Users/brandonlamer-connolly/code/Life-XP-iOS/frontend/Life-XP-iOS.xcodeproj \
  -scheme Life-XP-iOS \
  -destination 'platform=iOS Simulator,id=B346B89B-C586-442A-A238-7ABE19CB38DE'
```
Expected: PASS — confirms the new `addHabit` parameters don't break `AddHabitView`'s existing call or the `addHabit_appendsNewHabitWithCorrectProperties`/`addHabit_multipleHabitsAccumulate` tests.

- [ ] **Step 7: Commit**

```bash
git add frontend/Life-XP-iOS/ViewModels/UserViewModel.swift \
        frontend/Life-XP-iOS/ViewModels/UserViewModel+HealthHabits.swift \
        frontend/Life-XP-iOSTests/HealthHabitTests.swift
git commit -m "Add end-of-day headphone habit evaluation to UserViewModel

evaluateHealthHabits() scores yesterday's average once per day via the
existing completeHabit() streak/XP path. Tested with a synchronous fake
fetcher — no live HealthKit dependency in the test suite."
```

---

### Task 5: CloudKit sync for the new `Habit` fields

**Files:**
- Modify: `frontend/Life-XP-iOS/Managers/CloudKitManager.swift` (`saveHabits` lines 78–118, `fetchHabits` lines 120–152)

**Interfaces:**
- Consumes: `Habit.trackingType`/`maxDecibels`/`lastEvaluatedHealthDate` (Task 1).
- No new public interface — purely extends existing serialization.

- [ ] **Step 1: Add the new fields to `saveHabits`' record construction**

In `saveHabits`, inside the `recordsToSave = habits.map { ... }` closure, after the existing `record["reminderTime"] = ...` block (around line 106):

```swift
                    record["trackingType"] = habit.trackingType.rawValue as CKRecordValue
                    if let maxDecibels = habit.maxDecibels {
                        record["maxDecibels"] = maxDecibels as CKRecordValue
                    }
                    if let lastEvaluatedHealthDate = habit.lastEvaluatedHealthDate {
                        record["lastEvaluatedHealthDate"] = lastEvaluatedHealthDate as CKRecordValue
                    }
```

- [ ] **Step 2: Add the new fields to `fetchHabits`' reconstruction**

In `fetchHabits`, inside the `records?.compactMap { ... }` closure, after the existing `habit.reminderTime = ...` line (around line 142):

```swift
                if let trackingTypeString = record["trackingType"] as? String,
                   let trackingType = HabitTrackingType(rawValue: trackingTypeString) {
                    habit.trackingType = trackingType
                }
                habit.maxDecibels = record["maxDecibels"] as? Double
                habit.lastEvaluatedHealthDate = record["lastEvaluatedHealthDate"] as? Date
```

(This mirrors the existing optional-decode-with-fallback pattern already used for `category` two lines above — records written before this change simply have no `trackingType` key, so `habit.trackingType` keeps its `.manual` default from the initializer.)

- [ ] **Step 3: Build to verify it compiles**

Run:
```bash
xcodebuild -project /Users/brandonlamer-connolly/code/Life-XP-iOS/frontend/Life-XP-iOS.xcodeproj \
  -scheme Life-XP-iOS \
  -destination 'platform=iOS Simulator,id=B346B89B-C586-442A-A238-7ABE19CB38DE' \
  build
```
Expected: BUILD SUCCEEDED. (No unit tests exist for `CloudKitManager` in this codebase — it talks to a live `CKContainer` and isn't covered by the existing Swift Testing suite; this task follows that established precedent rather than introducing new test infrastructure.)

- [ ] **Step 4: Commit**

```bash
git add frontend/Life-XP-iOS/Managers/CloudKitManager.swift
git commit -m "Sync Habit trackingType/maxDecibels/lastEvaluatedHealthDate via CloudKit"
```

---

### Task 6: Wire evaluation and live refresh into the app

**Files:**
- Modify: `frontend/Life-XP-iOS/ContentView.swift` (the `.onAppear` block, lines 62–69, and the `HabitListView(...)` call, line 22)
- Modify: `frontend/Life-XP-iOS/Views/HabitListView.swift` (`HabitListView` struct)

**Interfaces:**
- Consumes: `UserViewModel.evaluateHealthHabits(using:)`, `refreshHeadphoneExposure(for:using:)` (Task 4). `HealthKitManager` already conforms to `HeadphoneExposureFetching` (Task 3), so it can be passed directly as the `using:` argument.

- [ ] **Step 1: Call `evaluateHealthHabits` from `ContentView`'s existing authorization flow**

In `frontend/Life-XP-iOS/ContentView.swift`, update the `.onAppear` block (lines 62–69):

```swift
        .onAppear {
            healthKitManager.requestAuthorization { success, _ in
                if success {
                    healthKitManager.fetchTodayHealthData()
                    userViewModel.refreshHealthKitGoals(using: healthKitManager)
                    userViewModel.evaluateHealthHabits(using: healthKitManager)
                }
            }
        }
```

- [ ] **Step 2: Pass `healthKitManager` into `HabitListView`**

Still in `ContentView.swift`, update the `HabitListView` call (line 22):

```swift
                HabitListView(viewModel: userViewModel, healthKitManager: healthKitManager)
```

- [ ] **Step 3: Accept `healthKitManager` in `HabitListView` and refresh each headphone habit on appear**

In `frontend/Life-XP-iOS/Views/HabitListView.swift`, add the property and an `onAppear` to `HabitListView`:

```swift
struct HabitListView: View {
    @ObservedObject var viewModel: UserViewModel
    @ObservedObject var healthKitManager: HealthKitManager
    @State private var showingAddHabit = false
    @State private var showingLockInView = false

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Your Daily Habits")) {
                    ForEach(viewModel.habits) { habit in
                        HabitRowView(habit: habit, onComplete: {
                            viewModel.completeHabit(habit)
                        })
                        .onAppear {
                            viewModel.refreshHeadphoneExposure(for: habit, using: healthKitManager)
                        }
                    }
                    .onDelete(perform: viewModel.deleteHabit)
                }
            }
```

(Only the `struct HabitListView` property declarations and the `ForEach` body change; the rest of `body` — toolbar, sheets, `.navigationTitle` — stays as-is.)

- [ ] **Step 4: Update the `#Preview` for `HabitListView`**

At the bottom of `HabitListView.swift`, update the preview (currently `HabitListView(viewModel: .preview)`) to supply the new required parameter:

```swift
#Preview {
    HabitListView(viewModel: .preview, healthKitManager: HealthKitManager())
}
```

- [ ] **Step 5: Build to verify it compiles**

Run:
```bash
xcodebuild -project /Users/brandonlamer-connolly/code/Life-XP-iOS/frontend/Life-XP-iOS.xcodeproj \
  -scheme Life-XP-iOS \
  -destination 'platform=iOS Simulator,id=B346B89B-C586-442A-A238-7ABE19CB38DE' \
  build
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Manually verify no regression in the simulator**

Boot the simulator and run the app (`xcodebuild` build already produces the `.app`; launch via Xcode or `xcrun simctl install`/`launch` against UDID `B346B89B-C586-442A-A238-7ABE19CB38DE`). Confirm: the Habits tab still lists the 3 default habits and tapping the circle still completes them — this task only adds plumbing, no visible behavior change yet (the UI for the new habit type is Tasks 7–8).

- [ ] **Step 7: Commit**

```bash
git add frontend/Life-XP-iOS/ContentView.swift frontend/Life-XP-iOS/Views/HabitListView.swift
git commit -m "Wire headphone habit evaluation and live refresh into app launch flow"
```

---

### Task 7: `AddHabitView` — tracking type picker and dB threshold input

**Files:**
- Modify: `frontend/Life-XP-iOS/Views/AddHabitView.swift`
- Modify: `frontend/Life-XP-iOS/ContentView.swift` (pass `healthKitManager` into `AddHabitView` via `HabitListView`'s sheet — see Step 3)
- Modify: `frontend/Life-XP-iOS/Views/HabitListView.swift` (thread `healthKitManager` into the `AddHabitView` sheet)

**Interfaces:**
- Consumes: `HabitTrackingType` (Task 1), `UserViewModel.addHabit(...trackingType:maxDecibels:...)` (Task 4), `HealthKitManager.requestAuthorization` (pre-existing).

- [ ] **Step 1: Add tracking-type state and UI to `AddHabitView`**

Replace the full contents of `frontend/Life-XP-iOS/Views/AddHabitView.swift`:

```swift
import SwiftUI

struct AddHabitView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: UserViewModel
    @ObservedObject var healthKitManager: HealthKitManager

    @State private var title = ""
    @State private var description = ""
    @State private var xpReward = 10
    @State private var category: HabitCategory = .physical
    @State private var trackingType: HabitTrackingType = .manual
    @State private var maxDecibels: Double = 85
    @State private var enableReminder = false
    @State private var reminderTime = Calendar.current.date(
        bySettingHour: 9, minute: 0, second: 0, of: Date()
    ) ?? Date()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Habit Details")) {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description)
                }

                Section(header: Text("Category")) {
                    Picker("Category", selection: $category) {
                        ForEach(HabitCategory.allCases, id: \.self) { cat in
                            Label(cat.displayName, systemImage: cat.icon).tag(cat)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("Rewards +1 \(category.statBoost.rawValue.capitalized) on completion")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("Tracking")) {
                    Picker("Tracking", selection: $trackingType) {
                        ForEach(HabitTrackingType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    if trackingType == .headphoneAudioExposure {
                        Stepper("Max \(Int(maxDecibels)) dB", value: $maxDecibels, in: 60...100, step: 1)
                        if !healthKitManager.isAuthorized {
                            Text("Requires HealthKit permission — you'll be prompted when you add this habit.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section(header: Text("Reward")) {
                    Stepper("\(xpReward) XP", value: $xpReward, in: 5...100, step: 5)
                }

                Section(header: Text("Reminder")) {
                    Toggle("Daily Reminder", isOn: $enableReminder)
                    if enableReminder {
                        DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                }
            }
            .navigationTitle("New Habit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if trackingType == .headphoneAudioExposure {
                            healthKitManager.requestAuthorization { _, _ in }
                        }
                        viewModel.addHabit(
                            title: title, description: description,
                            experiencePoints: xpReward, category: category,
                            trackingType: trackingType,
                            maxDecibels: trackingType == .headphoneAudioExposure ? maxDecibels : nil,
                            reminderTime: enableReminder ? reminderTime : nil
                        )
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

#Preview {
    AddHabitView(viewModel: .preview, healthKitManager: HealthKitManager())
}
```

- [ ] **Step 2: Thread `healthKitManager` through `HabitListView`'s sheet**

In `frontend/Life-XP-iOS/Views/HabitListView.swift`, update the `.sheet(isPresented: $showingAddHabit)` block:

```swift
            .sheet(isPresented: $showingAddHabit) {
                AddHabitView(viewModel: viewModel, healthKitManager: healthKitManager)
            }
```

- [ ] **Step 3: Build to verify it compiles**

Run:
```bash
xcodebuild -project /Users/brandonlamer-connolly/code/Life-XP-iOS/frontend/Life-XP-iOS.xcodeproj \
  -scheme Life-XP-iOS \
  -destination 'platform=iOS Simulator,id=B346B89B-C586-442A-A238-7ABE19CB38DE' \
  build
```
Expected: BUILD SUCCEEDED. (No unit tests — SwiftUI view bodies aren't covered by the existing Swift Testing suite in this codebase; verify manually in Step 4.)

- [ ] **Step 4: Manually verify in the simulator**

Launch the app, go to the Habits tab, tap "+". Confirm: a "Tracking" section appears with a "Manual"/"Headphone Audio Exposure (HealthKit)" picker; selecting the headphone option reveals a dB stepper starting at 85; tapping "Add" with that option selected triggers the HealthKit permission dialog (first time) and creates the habit.

- [ ] **Step 5: Commit**

```bash
git add frontend/Life-XP-iOS/Views/AddHabitView.swift frontend/Life-XP-iOS/Views/HabitListView.swift
git commit -m "Add tracking-type picker and dB threshold input to AddHabitView"
```

---

### Task 8: `HabitRowView` — live dB readout and disabled manual completion

**Files:**
- Modify: `frontend/Life-XP-iOS/Views/HabitListView.swift` (`HabitRowView` struct and its call site in `HabitListView.body`)

**Interfaces:**
- Consumes: `viewModel.headphoneAverages[habit.id]` (Task 4), `habit.trackingType`/`maxDecibels` (Task 1), `healthKitManager.isAuthorized`/`HKHealthStore.isHealthDataAvailable()` (pre-existing).

- [ ] **Step 1: Pass the live average and authorization state into `HabitRowView`**

In `HabitListView.body`, update the `ForEach`:

```swift
                    ForEach(viewModel.habits) { habit in
                        HabitRowView(
                            habit: habit,
                            liveAverage: viewModel.headphoneAverages[habit.id],
                            isHealthKitAvailable: HKHealthStore.isHealthDataAvailable() && healthKitManager.isAuthorized,
                            onComplete: {
                                viewModel.completeHabit(habit)
                            }
                        )
                        .onAppear {
                            viewModel.refreshHeadphoneExposure(for: habit, using: healthKitManager)
                        }
                    }
```

Add `import HealthKit` to the top of `HabitListView.swift` (needed for `HKHealthStore.isHealthDataAvailable()`).

- [ ] **Step 2: Update `HabitRowView` to show a live readout instead of the complete button for HealthKit habits**

Replace the `HabitRowView` struct:

```swift
struct HabitRowView: View {
    let habit: Habit
    var liveAverage: Double? = nil
    var isHealthKitAvailable: Bool = true
    let onComplete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: habit.category.icon)
                        .foregroundColor(categoryColor(habit.category))
                        .font(.system(size: 11))
                    Text(habit.title)
                        .font(.headline)
                        .strikethrough(habit.isCompletedToday, color: .secondary)
                }
                Text(habit.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 10))
                        Text("\(habit.xpReward) XP")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    if habit.currentStreak > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(habit.currentStreak >= 7 ? .red : .orange)
                                .font(.system(size: 10))
                            Text("\(habit.currentStreak)d")
                                .font(.caption2)
                                .foregroundColor(habit.currentStreak >= 7 ? .red : .orange)
                                .fontWeight(habit.currentStreak >= 7 ? .bold : .regular)
                        }
                    }
                    if habit.reminderTime != nil {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 9))
                    }
                }
                if habit.trackingType == .headphoneAudioExposure && !isHealthKitAvailable {
                    Text("HealthKit unavailable — this habit won't update automatically")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            if habit.trackingType == .headphoneAudioExposure {
                VStack(alignment: .trailing, spacing: 2) {
                    if let liveAverage {
                        Text("\(Int(liveAverage)) dB")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(liveAverage <= (habit.maxDecibels ?? 85) ? .green : .red)
                        Text("avg today")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("—").foregroundColor(.secondary)
                    }
                }
            } else {
                Button(action: onComplete) {
                    Image(systemName: habit.isCompletedToday ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(habit.isCompletedToday ? .green : .blue)
                        .font(.title2)
                }
                .disabled(habit.isCompletedToday)
            }
        }
        .padding(.vertical, 4)
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run:
```bash
xcodebuild -project /Users/brandonlamer-connolly/code/Life-XP-iOS/frontend/Life-XP-iOS.xcodeproj \
  -scheme Life-XP-iOS \
  -destination 'platform=iOS Simulator,id=B346B89B-C586-442A-A238-7ABE19CB38DE' \
  build
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Manually verify in the simulator**

Add a headphone habit via the flow verified in Task 7. Confirm the row shows "— " (no data yet, since the simulator has no real headphone exposure samples) instead of a tap-to-complete circle, and that existing manual habits (Drink Water, Morning Run, Read for 30m) are unaffected and still completable by tapping the circle.

- [ ] **Step 4: Commit**

```bash
git add frontend/Life-XP-iOS/Views/HabitListView.swift
git commit -m "Show live dB readout for headphone habits, disable manual completion"
```

---

## Self-Review Notes

- **Spec coverage:** all 8 sections of the spec map to a task — Section 1→Task 1, Section 2→Task 2, Section 3→Task 3, Section 4→Task 4, Section 5→Tasks 6–8, Section 6→Task 5, Section 7→Tasks 1/2/4 (tests are embedded per-task, not a separate task, since each piece of logic is tested where it's introduced).
- **Refinement vs. spec:** Task 2/3/4 introduce a `HeadphoneExposureFetching` protocol not named in the spec's Section 3/4 prose (which said `using: HealthKitManager` directly). This is a strict refinement, not a scope change — it's what makes the spec's own required "unit tests for... habit evaluation" (Section 7 / ticket AC) deterministic and independent of live HealthKit, which a direct `HealthKitManager` dependency couldn't achieve in a test target.
- **Type consistency check:** `evaluateHeadphoneHabit(average:maxDecibels:)` (Task 2) is called with the same signature in Task 4's `evaluateHealthHabits`. `HeadphoneExposureFetching.fetchHeadphoneExposure(for:completion:)` (Task 2) matches `HealthKitManager`'s new method (Task 3) and the `FakeExposureFetcher`/`UserViewModel+HealthHabits` call sites (Task 4) exactly. `HabitTrackingType.headphoneAudioExposure` (Task 1) is referenced identically in Tasks 4, 5, 7, 8.
- **No placeholders:** every step above contains complete, concrete code — no "add error handling here" or "similar to Task N" stand-ins.
