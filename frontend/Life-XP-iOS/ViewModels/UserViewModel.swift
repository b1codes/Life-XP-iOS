import Foundation
import Combine
import SwiftUI

class UserViewModel: ObservableObject {
    @Published var user: LifeXPUser = LifeXPUser() { didSet { saveUser() } }
    @Published var habits: [Habit] = [] { didSet { saveHabits() } }
    @Published var headphoneAverages: [UUID: Double] = [:]
    @Published var goals: [Goal] = [] { didSet { saveGoals() } }

    @Published var showingMilestoneReward = false
    @Published var lastMilestoneMessage = ""

    @Published var showingLockInReward = false
    @Published var lockInRewardMessage = ""

    // Level Up State
    @Published var showingLevelUp = false
    @Published var lastLeveledUpTo = 0

    // Shop Items
    @Published var shopItems: [Item] = [
        Item(
            name: "Dumbbells",
            description: "+5 Strength",
            icon: "dumbbell.fill",
            price: 50,
            statBoost: .strength,
            boostAmount: 5
        ),
        Item(
            name: "Encyclopedia",
            description: "+5 Intelligence",
            icon: "book.fill",
            price: 75,
            statBoost: .intelligence,
            boostAmount: 5
        ),
        Item(
            name: "Herbal Tea",
            description: "+5 Vitality",
            icon: "cup.and.saucer.fill",
            price: 30,
            statBoost: .vitality,
            boostAmount: 5
        ),
        Item(
            name: "Stylish Fedora",
            description: "+5 Charisma",
            icon: "hat.widebrim.fill",
            price: 100,
            statBoost: .charisma,
            boostAmount: 5
        )
    ]

    // CloudKit sync state
    @Published var isSyncing = false
    @Published var lastCloudSync: Date?

    // Social / Leaderboard
    @Published var leaderboard: [PublicProfile] = []
    @Published var isLoadingLeaderboard = false

    private var activeSyncCount = 0 { didSet { isSyncing = activeSyncCount > 0 } }
    private var midnightObserver: NSObjectProtocol?

    // Conversion Factors
    private let stepsToXP = 100 // 100 steps = 1 XP
    private let kcalToXP = 10   // 10 kcal = 1 XP
    private let waterToXP = 0.25 // 0.25L (1 cup) = 5 XP
    private let sleepToXP = 1.0  // 1 hour = 10 XP

    init(skipCloudSync: Bool = false) {
        loadUser()
        loadHabits()
        loadGoals()
        requestNotificationPermission()
        resetBrokenStreaks()
        evaluateLockIn()
        scheduleAllReminders()
        midnightObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.significantTimeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.user.checkNewDay()
            self?.evaluateLockIn()
            self?.resetBrokenStreaks()
        }
    }

    deinit { midnightObserver.map { NotificationCenter.default.removeObserver($0) } }

    func fetchFromCloud() {
        activeSyncCount += 1
        CloudKitManager.shared.fetchUserStats { [weak self] result in
            DispatchQueue.main.async {
                self?.activeSyncCount -= 1
                switch result {
                case .success(let cloudUser):
                    // Simple merge: take the one with more total XP/level
                    if cloudUser.level > self?.user.level ?? 0 ||
                       (cloudUser.level == self?.user.level ?? 0 && cloudUser.experience > self?.user.experience ?? 0) {
                        self?.user = cloudUser
                        self?.lastCloudSync = Date()
                    }
                case .failure(let error):
                    print("CloudKit Fetch Error: \(error.localizedDescription)")
                }
            }
        }

        activeSyncCount += 1
        CloudKitManager.shared.fetchHabits { [weak self] result in
            DispatchQueue.main.async {
                self?.activeSyncCount -= 1
                switch result {
                case .success(let cloudHabits):
                    if !cloudHabits.isEmpty {
                        self?.habits = cloudHabits
                    }
                case .failure(let error):
                    print("CloudKit Habits Fetch Error: \(error.localizedDescription)")
                }
            }
        }

        activeSyncCount += 1
        CloudKitManager.shared.fetchGoals { [weak self] result in
            DispatchQueue.main.async {
                self?.activeSyncCount -= 1
                switch result {
                case .success(let cloudGoals):
                    if !cloudGoals.isEmpty {
                        self?.goals = cloudGoals
                    }
                case .failure(let error):
                    print("CloudKit Goals Fetch Error: \(error.localizedDescription)")
                }
            }
        }
    }

    func uploadToCloud() {
        activeSyncCount += 1
        CloudKitManager.shared.saveUserStats(user) { [weak self] result in
            DispatchQueue.main.async {
                self?.activeSyncCount -= 1
                if case .success = result {
                    self?.lastCloudSync = Date()
                }
            }
        }

        activeSyncCount += 1
        CloudKitManager.shared.saveHabits(habits) { [weak self] error in
            DispatchQueue.main.async {
                self?.activeSyncCount -= 1
                if let error = error {
                    print("CloudKit Habits Upload Error: \(error.localizedDescription)")
                }
            }
        }

        activeSyncCount += 1
        CloudKitManager.shared.saveGoals(goals) { [weak self] error in
            DispatchQueue.main.async {
                self?.activeSyncCount -= 1
                if let error = error {
                    print("CloudKit Goals Upload Error: \(error.localizedDescription)")
                }
            }
        }

        uploadPublicProfile()
    }

    func syncHealthData(steps: Int, calories: Double, sleep: Double, water: Double) {
        user.checkNewDay()

        let newSteps = steps - user.lastSyncedSteps
        let newCalories = calories - user.lastSyncedCalories
        let newSleep = sleep - user.lastSyncedSleep
        let newWater = water - user.lastSyncedWater

        var totalXPGained = 0

        // Steps
        if newSteps >= stepsToXP {
            let experiencePoints = newSteps / stepsToXP
            totalXPGained += experiencePoints
            user.lastSyncedSteps += experiencePoints * stepsToXP
        }

        // Calories
        if newCalories >= Double(kcalToXP) {
            let experiencePoints = Int(newCalories / Double(kcalToXP))
            totalXPGained += experiencePoints
            user.lastSyncedCalories += Double(experiencePoints * kcalToXP)
        }

        // Water
        if newWater >= waterToXP {
            let experiencePoints = Int(newWater / waterToXP) * 5
            totalXPGained += experiencePoints
            user.lastSyncedWater += Double(Int(newWater / waterToXP)) * waterToXP
            user.intelligence += 1 // hydration helps the brain!
        }

        // Sleep
        if newSleep >= sleepToXP {
            let experiencePoints = Int(newSleep / sleepToXP) * 10
            totalXPGained += experiencePoints
            user.lastSyncedSleep += Double(Int(newSleep / sleepToXP)) * sleepToXP
            user.vitality += 1 // sleep restores vitality
        }

        if totalXPGained > 0 {
            addExperience(totalXPGained)

            // Random physical boost
            if Int.random(in: 1...5) == 1 {
                user.strength += 1
            }

            uploadToCloud() // Auto-sync to cloud when XP is gained
        }

        user.lastSyncDate = Date()
    }

    private func saveUser() {
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: "LifeXPUser")
            // Don't auto-upload every single change to avoid CloudKit rate limits,
            // but syncHealthData and completeHabit will trigger it.
        }
    }

    private func loadUser() {
        if let data = UserDefaults.standard.data(forKey: "LifeXPUser"),
           let decoded = try? JSONDecoder().decode(LifeXPUser.self, from: data) {
            user = decoded
        }
    }

    private func saveHabits() {
        if let encoded = try? JSONEncoder().encode(habits) {
            UserDefaults.standard.set(encoded, forKey: "LifeXPHabits")
        }
    }

    private func saveGoals() {
        if let encoded = try? JSONEncoder().encode(goals) {
            UserDefaults.standard.set(encoded, forKey: "LifeXPGoals")
        }
    }

    private func loadGoals() {
        if let data = UserDefaults.standard.data(forKey: "LifeXPGoals"),
           let decoded = try? JSONDecoder().decode([Goal].self, from: data) {
            goals = decoded
        }
    }

    private func loadHabits() {
        if let data = UserDefaults.standard.data(forKey: "LifeXPHabits"),
           let decoded = try? JSONDecoder().decode([Habit].self, from: data) {
            habits = decoded
        } else {
            habits = [
                Habit(title: "Drink Water", description: "Stay hydrated",
                      xpReward: 10, frequency: .daily, category: .health),
                Habit(title: "Morning Run", description: "30-minute jog",
                      xpReward: 50, frequency: .daily, category: .physical),
                Habit(title: "Read for 30m", description: "Expand your mind",
                      xpReward: 30, frequency: .daily, category: .mental)
            ]
        }
    }

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

    func deleteHabit(at offsets: IndexSet) {
        offsets.forEach { cancelReminder(for: habits[$0]) }
        habits.remove(atOffsets: offsets)
        saveHabits()
        uploadToCloud()
    }

    func completeHabit(_ habit: Habit) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        let prevDate = habits[index].lastCompletedDate
        habits[index].lastCompletedDate = Date()
        let newStreak = prevDate.map { Calendar.current.isDateInYesterday($0) } == true
            ? habits[index].currentStreak + 1
            : 1
        habits[index].currentStreak = newStreak
        if newStreak > habits[index].longestStreak { habits[index].longestStreak = newStreak }

        // Intercept rewards if habit is in an active Lock In challenge
        if let activeChallenge = user.activeLockIn, activeChallenge.habitIDs.contains(habit.id) {
            // Deferred rewards - will be awarded during daily evaluation
        } else {
            addExperience(habit.xpReward)
            user.gold += habit.xpReward / 2 + user.charisma / 10
            switch habit.category {
            case .physical: if Int.random(in: 1...3) == 1 { user.strength += 1 }
            case .mental:   if Int.random(in: 1...3) == 1 { user.intelligence += 1 }
            case .health:   if Int.random(in: 1...3) == 1 { user.vitality += 1 }
            case .social:   user.charisma += 1
            }
        }

        saveHabits()
        uploadToCloud()
    }

    func buyItem(_ item: Item) {
        guard user.gold >= item.price else { return }

        user.gold -= item.price
        user.inventory.append(item)

        // Apply stat boost immediately
        if let boost = item.statBoost {
            switch boost {
            case .strength: user.strength += item.boostAmount
            case .intelligence: user.intelligence += item.boostAmount
            case .vitality: user.vitality += item.boostAmount
            case .charisma: user.charisma += item.boostAmount
            }
        }

        saveUser()
        uploadToCloud()
    }

    func addGoal(_ goal: Goal) {
        goals.append(goal)
        uploadToCloud()
    }

    func deleteGoal(at offsets: IndexSet) {
        goals.remove(atOffsets: offsets)
        uploadToCloud()
    }

    func updateManualProgress(goalId: UUID, newValue: Double) {
        guard let index = goals.firstIndex(where: { $0.id == goalId }) else { return }
        goals[index].currentProgress = newValue
        checkMilestones(for: goals[index])
        uploadToCloud()
    }

    func updateGoalPhoto(goalId: UUID, photoData: Data?) {
        guard let index = goals.firstIndex(where: { $0.id == goalId }) else { return }
        goals[index].photoData = photoData
    }

    func refreshHealthKitGoals(using healthKitManager: HealthKitManager) {
        let activeGoals = goals.filter {
            !$0.isCompleted && ($0.trackingType == .steps || $0.trackingType == .calories)
        }
        for goal in activeGoals {
            guard let index = goals.firstIndex(where: { $0.id == goal.id }) else { continue }
            let start = goal.startDate
            let end = Date()
            switch goal.trackingType {
            case .steps:
                healthKitManager.fetchCumulativeSteps(from: start, to: end) { [weak self] total in
                    guard let self else { return }
                    if let idx = self.goals.firstIndex(where: { $0.id == goal.id }) {
                        self.goals[idx].currentProgress = total
                        self.checkMilestones(for: self.goals[idx])
                        self.uploadToCloud()
                    }
                }
            case .calories:
                healthKitManager.fetchCumulativeCalories(from: start, to: end) { [weak self] total in
                    guard let self else { return }
                    if let idx = self.goals.firstIndex(where: { $0.id == goal.id }) {
                        self.goals[idx].currentProgress = total
                        self.checkMilestones(for: self.goals[idx])
                        self.uploadToCloud()
                    }
                }
            case .manual:
                break
            }
        }
    }

    func addExperience(_ amount: Int) {
        user.experience += amount

        // Level up logic
        while user.experience >= user.xpToNextLevel {
            user.experience -= user.xpToNextLevel
            user.level += 1
            lastLeveledUpTo = user.level

            // Bonus stats on level up
            user.strength += 1
            user.intelligence += 1
            user.vitality += 1

            // Bonus gold for reaching new heights
            user.gold += user.level * 20

            // Trigger animation state
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.showingLevelUp = true
            }
        }
    }

    func evaluateLockIn() {
        guard var challenge = user.activeLockIn else { return }

        let calendar = Calendar.current

        // Skip if already evaluated today
        if let lastEval = challenge.lastEvaluationDate, calendar.isDateInToday(lastEval) {
            return
        }

        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) else { return }

        // Check if all habits in the challenge were completed yesterday
        let challengeHabits = habits.filter { challenge.habitIDs.contains($0.id) }
        let allCompleted = challengeHabits.allSatisfy { habit in
            guard let lastCompleted = habit.lastCompletedDate else { return false }
            return calendar.isDate(lastCompleted, inSameDayAs: yesterday)
        }

        challenge.lastEvaluationDate = Date()

        if allCompleted {
            // Reward: Add XP and Gold (half XP) for all challenge habits
            let totalXP = challengeHabits.reduce(0) { $0 + $1.xpReward }
            addExperience(totalXP)
            user.gold += totalXP / 2

            // Check if challenge is finished
            if calendar.isDateInToday(challenge.endDate) || Date() > challenge.endDate {
                challenge.status = .completed

                // Completion Rewards
                addExperience(1000)
                user.gold += 500

                let trophy = Item(
                    name: "\(challenge.durationDays)-Day Lock In Trophy",
                    description: "Awarded for completing a Lock In challenge.",
                    icon: "lock.shield.fill",
                    price: 0,
                    statBoost: .vitality,
                    boostAmount: 10
                )
                user.inventory.append(trophy)

                lockInRewardMessage = "Challenge Complete! You earned 1000 XP, 500 Gold, and the \(challenge.durationDays)-Day Trophy!"
                showingLockInReward = true

                user.pastLockIns.append(challenge)
                user.activeLockIn = nil
            } else {
                user.activeLockIn = challenge
            }
        } else {
            // Strike!
            challenge.strikesCount += 1
            if challenge.strikesCount >= challenge.maxStrikes {
                challenge.status = .failed
                user.pastLockIns.append(challenge)
                user.activeLockIn = nil
            } else {
                user.activeLockIn = challenge
            }
        }

        saveUser()
        uploadToCloud()
    }
}
