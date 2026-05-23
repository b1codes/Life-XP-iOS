import Testing
import Foundation
@testable import Life_XP_iOS

// MARK: - LifeXPUser Model Tests

@Suite("LifeXPUser")
struct LifeXPUserTests {

    @Test func xpToNextLevel_equalsLevelTimes100() {
        var user = LifeXPUser()
        user.level = 1
        #expect(user.xpToNextLevel == 100)

        user.level = 5
        #expect(user.xpToNextLevel == 500)

        user.level = 10
        #expect(user.xpToNextLevel == 1000)
    }

    @Test func xpProgress_returnsCorrectFraction() {
        var user = LifeXPUser()
        user.level = 1
        user.experience = 50
        #expect(user.xpProgress == 0.5)
    }

    @Test func xpProgress_isZeroAtDefaultState() {
        let user = LifeXPUser()
        #expect(user.xpProgress == 0.0)
    }

    @Test func xpProgress_isOneAtFullXP() {
        var user = LifeXPUser()
        user.level = 1
        user.experience = 100
        #expect(user.xpProgress == 1.0)
    }

    @Test func checkNewDay_setsDateWhenNil() {
        var user = LifeXPUser()
        user.lastSyncDate = nil
        user.checkNewDay()
        #expect(user.lastSyncDate != nil)
    }

    @Test func checkNewDay_resetsAllCountersForYesterday() {
        var user = LifeXPUser()
        user.lastSyncedSteps = 5000
        user.lastSyncedCalories = 300.0
        user.lastSyncedSleep = 8.0
        user.lastSyncedWater = 2.0
        user.lastSyncDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())

        user.checkNewDay()

        #expect(user.lastSyncedSteps == 0)
        #expect(user.lastSyncedCalories == 0.0)
        #expect(user.lastSyncedSleep == 0.0)
        #expect(user.lastSyncedWater == 0.0)
    }

    @Test func checkNewDay_doesNotResetCountersForToday() {
        var user = LifeXPUser()
        user.lastSyncedSteps = 5000
        user.lastSyncedCalories = 300.0
        user.lastSyncDate = Date()

        user.checkNewDay()

        #expect(user.lastSyncedSteps == 5000)
        #expect(user.lastSyncedCalories == 300.0)
    }
}

// MARK: - Habit Model Tests

@Suite("Habit")
struct HabitTests {

    @Test func isCompletedToday_falseWhenNeverCompleted() {
        let habit = Habit(title: "Exercise", description: "Work out", xpReward: 20, frequency: .daily)
        #expect(habit.isCompletedToday == false)
    }

    @Test func isCompletedToday_trueWhenCompletedToday() {
        var habit = Habit(title: "Exercise", description: "Work out", xpReward: 20, frequency: .daily)
        habit.lastCompletedDate = Date()
        #expect(habit.isCompletedToday == true)
    }

    @Test func isCompletedToday_falseWhenCompletedYesterday() {
        var habit = Habit(title: "Exercise", description: "Work out", xpReward: 20, frequency: .daily)
        habit.lastCompletedDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        #expect(habit.isCompletedToday == false)
    }

    @Test func isCompletedToday_falseWhenCompletedLastWeek() {
        var habit = Habit(title: "Exercise", description: "Work out", xpReward: 20, frequency: .weekly)
        habit.lastCompletedDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())
        #expect(habit.isCompletedToday == false)
    }
}

// MARK: - UserViewModel Tests

@Suite("UserViewModel")
struct UserViewModelTests {

    init() {
        UserDefaults.standard.removeObject(forKey: "LifeXPUser")
        UserDefaults.standard.removeObject(forKey: "LifeXPHabits")
        UserDefaults.standard.removeObject(forKey: "LifeXPGoals")
    }

    /// Creates a UserViewModel with a clean, predictable baseline state.
    @MainActor private func makeVM() -> UserViewModel {
        let vm = UserViewModel(skipCloudSync: true)
        vm.user = LifeXPUser()  // fresh user: level 1, 0 XP, 100 gold
        vm.habits = []
        return vm
    }

    // MARK: addExperience

    @Test @MainActor func addExperience_increasesXP() {
        let vm = makeVM()
        vm.addExperience(50)
        #expect(vm.user.experience == 50)
    }

    @Test @MainActor func addExperience_triggersLevelUpWhenThresholdReached() {
        let vm = makeVM()
        vm.addExperience(100) // level 1 threshold is 1 * 100 = 100
        #expect(vm.user.level == 2)
        #expect(vm.user.experience == 0)
    }

    @Test @MainActor func addExperience_carriesOverRemainingXPAfterLevelUp() {
        let vm = makeVM()
        vm.addExperience(150)
        #expect(vm.user.level == 2)
        #expect(vm.user.experience == 50)
    }

    @Test @MainActor func addExperience_supportsMultipleConsecutiveLevelUps() {
        let vm = makeVM()
        // Level 1 needs 100 XP, level 2 needs 200 XP → 300 total to hit level 3 with 0 remainder
        vm.addExperience(300)
        #expect(vm.user.level == 3)
        #expect(vm.user.experience == 0)
    }

    @Test @MainActor func addExperience_grantsBonusStatsOnLevelUp() {
        let vm = makeVM()
        let baseStrength = vm.user.strength
        let baseIntelligence = vm.user.intelligence
        let baseVitality = vm.user.vitality
        vm.addExperience(100)
        #expect(vm.user.strength == baseStrength + 1)
        #expect(vm.user.intelligence == baseIntelligence + 1)
        #expect(vm.user.vitality == baseVitality + 1)
    }

    @Test @MainActor func addExperience_grantsBonusGoldOnLevelUp() {
        let vm = makeVM()
        let baseGold = vm.user.gold
        vm.addExperience(100) // level 1 → 2; gold bonus = new level (2) * 20 = 40
        #expect(vm.user.gold == baseGold + 40)
    }

    @Test @MainActor func addExperience_doesNotLevelUpBelowThreshold() {
        let vm = makeVM()
        vm.addExperience(99)
        #expect(vm.user.level == 1)
        #expect(vm.user.experience == 99)
    }

    // MARK: completeHabit

    @Test @MainActor func completeHabit_marksHabitAsCompletedToday() {
        let vm = makeVM()
        vm.habits = [Habit(title: "Read", description: "", xpReward: 30, frequency: .daily)]
        vm.completeHabit(vm.habits[0])
        #expect(vm.habits[0].isCompletedToday == true)
    }

    @Test @MainActor func completeHabit_awardsCorrectXP() {
        let vm = makeVM()
        vm.habits = [Habit(title: "Read", description: "", xpReward: 30, frequency: .daily)]
        vm.completeHabit(vm.habits[0])
        #expect(vm.user.experience == 30)
    }

    @Test @MainActor func completeHabit_awardsHalfXPAsGold() {
        let vm = makeVM()
        vm.habits = [Habit(title: "Read", description: "", xpReward: 20, frequency: .daily)]
        let baseGold = vm.user.gold
        let bonus = vm.user.charisma / 10
        vm.completeHabit(vm.habits[0])
        #expect(vm.user.gold == baseGold + 10 + bonus) // xpReward / 2 = 10, plus charisma bonus
    }

    @Test @MainActor func completeHabit_doesNothingForUnknownHabitID() {
        let vm = makeVM()
        vm.habits = [Habit(title: "Read", description: "", xpReward: 30, frequency: .daily)]
        let unrelatedHabit = Habit(title: "Other", description: "", xpReward: 50, frequency: .daily)
        vm.completeHabit(unrelatedHabit)
        #expect(vm.user.experience == 0)
        #expect(vm.habits[0].isCompletedToday == false)
    }

    // MARK: buyItem

    @Test @MainActor func buyItem_deductsGoldFromUser() {
        let vm = makeVM()
        vm.user.gold = 100
        let item = Item(name: "Dumbbells", description: "+5 Str", icon: "dumbbell.fill", price: 50, statBoost: .strength, boostAmount: 5)
        vm.buyItem(item)
        #expect(vm.user.gold == 50)
    }

    @Test @MainActor func buyItem_addsItemToInventory() {
        let vm = makeVM()
        vm.user.gold = 100
        let item = Item(name: "Dumbbells", description: "+5 Str", icon: "dumbbell.fill", price: 50, statBoost: .strength, boostAmount: 5)
        vm.buyItem(item)
        #expect(vm.user.inventory.count == 1)
        #expect(vm.user.inventory[0].name == "Dumbbells")
    }

    @Test @MainActor func buyItem_appliesStrengthBoost() {
        let vm = makeVM()
        vm.user.gold = 200
        let base = vm.user.strength
        let item = Item(name: "Dumbbells", description: "+5 Str", icon: "dumbbell.fill", price: 50, statBoost: .strength, boostAmount: 5)
        vm.buyItem(item)
        #expect(vm.user.strength == base + 5)
    }

    @Test @MainActor func buyItem_appliesIntelligenceBoost() {
        let vm = makeVM()
        vm.user.gold = 200
        let base = vm.user.intelligence
        let item = Item(name: "Encyclopedia", description: "+5 Int", icon: "book.fill", price: 75, statBoost: .intelligence, boostAmount: 5)
        vm.buyItem(item)
        #expect(vm.user.intelligence == base + 5)
    }

    @Test @MainActor func buyItem_appliesVitalityBoost() {
        let vm = makeVM()
        vm.user.gold = 200
        let base = vm.user.vitality
        let item = Item(name: "Herbal Tea", description: "+5 Vit", icon: "cup.and.saucer.fill", price: 30, statBoost: .vitality, boostAmount: 5)
        vm.buyItem(item)
        #expect(vm.user.vitality == base + 5)
    }

    @Test @MainActor func buyItem_appliesCharismaBoost() {
        let vm = makeVM()
        vm.user.gold = 200
        let base = vm.user.charisma
        let item = Item(name: "Stylish Fedora", description: "+5 Cha", icon: "hat.widebrim.fill", price: 100, statBoost: .charisma, boostAmount: 5)
        vm.buyItem(item)
        #expect(vm.user.charisma == base + 5)
    }

    @Test @MainActor func buyItem_failsSilentlyWhenInsufficientGold() {
        let vm = makeVM()
        vm.user.gold = 20
        let item = Item(name: "Dumbbells", description: "+5 Str", icon: "dumbbell.fill", price: 50, statBoost: .strength, boostAmount: 5)
        vm.buyItem(item)
        #expect(vm.user.gold == 20)
        #expect(vm.user.inventory.isEmpty)
    }

    @Test @MainActor func buyItem_allowsPurchaseWithExactGold() {
        let vm = makeVM()
        vm.user.gold = 50
        let item = Item(name: "Dumbbells", description: "+5 Str", icon: "dumbbell.fill", price: 50, statBoost: .strength, boostAmount: 5)
        vm.buyItem(item)
        #expect(vm.user.gold == 0)
        #expect(vm.user.inventory.count == 1)
    }

    // MARK: addHabit

    @Test @MainActor func addHabit_appendsNewHabitWithCorrectProperties() {
        let vm = makeVM()
        vm.addHabit(title: "Meditate", description: "10 min mindfulness", experiencePoints: 15)
        #expect(vm.habits.count == 1)
        #expect(vm.habits[0].title == "Meditate")
        #expect(vm.habits[0].description == "10 min mindfulness")
        #expect(vm.habits[0].xpReward == 15)
        #expect(vm.habits[0].frequency == .daily)
    }

    @Test @MainActor func addHabit_multipleHabitsAccumulate() {
        let vm = makeVM()
        vm.addHabit(title: "Habit A", description: "", experiencePoints: 10)
        vm.addHabit(title: "Habit B", description: "", experiencePoints: 20)
        #expect(vm.habits.count == 2)
    }

    // MARK: deleteHabit

    @Test @MainActor func deleteHabit_removesCorrectHabit() {
        let vm = makeVM()
        vm.habits = [
            Habit(title: "Alpha", description: "", xpReward: 10, frequency: .daily),
            Habit(title: "Beta", description: "", xpReward: 20, frequency: .daily)
        ]
        vm.deleteHabit(at: IndexSet(integer: 0))
        #expect(vm.habits.count == 1)
        #expect(vm.habits[0].title == "Beta")
    }

    @Test @MainActor func deleteHabit_removesLastElement() {
        let vm = makeVM()
        vm.habits = [
            Habit(title: "Alpha", description: "", xpReward: 10, frequency: .daily),
            Habit(title: "Beta", description: "", xpReward: 20, frequency: .daily)
        ]
        vm.deleteHabit(at: IndexSet(integer: 1))
        #expect(vm.habits.count == 1)
        #expect(vm.habits[0].title == "Alpha")
    }

    // MARK: syncHealthData

    @Test @MainActor func syncHealthData_awardsXPForSteps() {
        let vm = makeVM()
        // 1000 steps / 100 = 10 XP
        vm.syncHealthData(steps: 1000, calories: 0, sleep: 0, water: 0)
        #expect(vm.user.experience == 10)
    }

    @Test @MainActor func syncHealthData_noXPWhenStepsBelowThreshold() {
        let vm = makeVM()
        vm.syncHealthData(steps: 50, calories: 0, sleep: 0, water: 0)
        #expect(vm.user.experience == 0)
    }

    @Test @MainActor func syncHealthData_onlyCountsIncrementalSteps() {
        let vm = makeVM()
        vm.user.lastSyncedSteps = 500
        // Total 1000, last synced 500 → new 500 → 5 XP
        vm.syncHealthData(steps: 1000, calories: 0, sleep: 0, water: 0)
        #expect(vm.user.experience == 5)
    }

    @Test @MainActor func syncHealthData_updatesLastSyncedSteps() {
        let vm = makeVM()
        vm.syncHealthData(steps: 1000, calories: 0, sleep: 0, water: 0)
        // Consumed 1000 steps (10 XP × 100 steps/XP)
        #expect(vm.user.lastSyncedSteps == 1000)
    }

    @Test @MainActor func syncHealthData_awardsXPForCalories() {
        let vm = makeVM()
        // 100 kcal / 10 = 10 XP
        vm.syncHealthData(steps: 0, calories: 100, sleep: 0, water: 0)
        #expect(vm.user.experience == 10)
    }

    @Test @MainActor func syncHealthData_noXPWhenCaloriesBelowThreshold() {
        let vm = makeVM()
        vm.syncHealthData(steps: 0, calories: 5.0, sleep: 0, water: 0)
        #expect(vm.user.experience == 0)
    }

    @Test @MainActor func syncHealthData_awardsXPAndIntelligenceForWater() {
        let vm = makeVM()
        let baseIntelligence = vm.user.intelligence
        // 0.5L / 0.25 = 2 cups × 5 XP = 10 XP, +1 Intelligence
        vm.syncHealthData(steps: 0, calories: 0, sleep: 0, water: 0.5)
        #expect(vm.user.experience == 10)
        #expect(vm.user.intelligence == baseIntelligence + 1)
    }

    @Test @MainActor func syncHealthData_noXPWhenWaterBelowThreshold() {
        let vm = makeVM()
        let baseIntelligence = vm.user.intelligence
        vm.syncHealthData(steps: 0, calories: 0, sleep: 0, water: 0.1)
        #expect(vm.user.experience == 0)
        #expect(vm.user.intelligence == baseIntelligence)
    }

    @Test @MainActor func syncHealthData_awardsXPAndVitalityForSleep() {
        let vm = makeVM()
        let baseVitality = vm.user.vitality
        // 8 hours × 10 XP = 80 XP, +1 Vitality
        vm.syncHealthData(steps: 0, calories: 0, sleep: 8.0, water: 0)
        #expect(vm.user.experience == 80)
        #expect(vm.user.vitality == baseVitality + 1)
    }

    @Test @MainActor func syncHealthData_noXPWhenSleepBelowThreshold() {
        let vm = makeVM()
        let baseVitality = vm.user.vitality
        vm.syncHealthData(steps: 0, calories: 0, sleep: 0.5, water: 0)
        #expect(vm.user.experience == 0)
        #expect(vm.user.vitality == baseVitality)
    }

    @Test @MainActor func syncHealthData_combinesXPFromMultipleSources() {
        let vm = makeVM()
        // 1000 steps = 10 XP, 100 kcal = 10 XP → 20 XP total
        vm.syncHealthData(steps: 1000, calories: 100, sleep: 0, water: 0)
        #expect(vm.user.experience == 20)
    }
}

// MARK: - Goal CRUD Tests

@Suite("Goal CRUD")
struct GoalCRUDTests {

    init() {
        UserDefaults.standard.removeObject(forKey: "LifeXPUser")
        UserDefaults.standard.removeObject(forKey: "LifeXPHabits")
        UserDefaults.standard.removeObject(forKey: "LifeXPGoals")
    }

    @MainActor private func makeVM() -> UserViewModel {
        let vm = UserViewModel(skipCloudSync: true)
        vm.user = LifeXPUser()
        vm.habits = []
        vm.goals = []
        return vm
    }

    private func makeGoal(
        title: String = "Run a Marathon",
        category: GoalCategory = .fitness,
        trackingType: GoalTrackingType = .manual,
        targetValue: Double = 100
    ) -> Goal {
        Goal(
            title: title,
            description: "Test goal",
            category: category,
            trackingType: trackingType,
            targetValue: targetValue
        )
    }

    @Test @MainActor func addGoal_appendsGoalToList() {
        let vm = makeVM()
        let goal = makeGoal()
        vm.addGoal(goal)
        #expect(vm.goals.count == 1)
        #expect(vm.goals[0].title == "Run a Marathon")
    }

    @Test @MainActor func addGoal_multipleGoalsAccumulate() {
        let vm = makeVM()
        vm.addGoal(makeGoal(title: "Goal A"))
        vm.addGoal(makeGoal(title: "Goal B"))
        #expect(vm.goals.count == 2)
    }

    @Test @MainActor func deleteGoal_removesCorrectGoal() {
        let vm = makeVM()
        vm.addGoal(makeGoal(title: "Alpha"))
        vm.addGoal(makeGoal(title: "Beta"))
        vm.deleteGoal(at: IndexSet(integer: 0))
        #expect(vm.goals.count == 1)
        #expect(vm.goals[0].title == "Beta")
    }

    @Test @MainActor func updateManualProgress_setsCurrentProgress() {
        let vm = makeVM()
        let goal = makeGoal(targetValue: 100)
        vm.addGoal(goal)
        vm.updateManualProgress(goalId: goal.id, newValue: 50)
        #expect(vm.goals[0].currentProgress == 50)
    }

    @Test @MainActor func updateManualProgress_doesNothingForUnknownId() {
        let vm = makeVM()
        vm.addGoal(makeGoal(targetValue: 100))
        let unknownId = UUID()
        vm.updateManualProgress(goalId: unknownId, newValue: 50)
        #expect(vm.goals[0].currentProgress == 0)
    }
}

// MARK: - Milestone Reward Tests

@Suite("Milestone Rewards")
struct MilestoneTests {

    init() {
        UserDefaults.standard.removeObject(forKey: "LifeXPUser")
        UserDefaults.standard.removeObject(forKey: "LifeXPHabits")
        UserDefaults.standard.removeObject(forKey: "LifeXPGoals")
    }

    @MainActor private func makeVM() -> UserViewModel {
        let vm = UserViewModel(skipCloudSync: true)
        vm.user = LifeXPUser()
        vm.habits = []
        vm.goals = []
        return vm
    }

    private func makeGoal(category: GoalCategory = .fitness, targetValue: Double = 100) -> Goal {
        Goal(title: "Test Goal", description: "desc", category: category,
             trackingType: .manual, targetValue: targetValue)
    }

    @Test @MainActor func milestone25_awardsCorrectXPAndGold() {
        let vm = makeVM()
        let goal = makeGoal(targetValue: 100)
        vm.addGoal(goal)
        let baseXP = vm.user.experience
        let baseGold = vm.user.gold
        vm.updateManualProgress(goalId: goal.id, newValue: 25)
        #expect(vm.user.experience == baseXP + 25)
        #expect(vm.user.gold == baseGold + 10)
    }

    @Test @MainActor func milestone50_awardsCorrectXPAndGold() {
        let vm = makeVM()
        let goal = makeGoal(targetValue: 100)
        vm.addGoal(goal)
        let baseXP = vm.user.experience
        let baseGold = vm.user.gold
        vm.updateManualProgress(goalId: goal.id, newValue: 50)
        // 25% and 50% both fire: 25+50=75 XP, 10+25=35 gold
        #expect(vm.user.experience == baseXP + 75)
        #expect(vm.user.gold == baseGold + 35)
    }

    @Test @MainActor func milestone100_awardsCorrectXPAndGold() {
        let vm = makeVM()
        let goal = makeGoal(targetValue: 100)
        vm.addGoal(goal)
        let baseGold = vm.user.gold

        // All four milestones fire: 25+50+100+200=375 XP, 10+25+50+100=185 gold
        vm.updateManualProgress(goalId: goal.id, newValue: 100)

        // At level 1, 375 XP leads to level 3 (100 to lvl 2, 200 to lvl 3) with 75 XP remaining
        #expect(vm.user.level == 3)
        #expect(vm.user.experience == 75)

        // Gold: 185 from milestones + level up bonuses (Lvl 2: 40, Lvl 3: 60) = 285 total gold gain
        #expect(vm.user.gold == baseGold + 185 + 100)
    }

    @Test @MainActor func milestone25_doesNotDoubleAward() {
        let vm = makeVM()
        let goal = makeGoal(targetValue: 100)
        vm.addGoal(goal)
        vm.updateManualProgress(goalId: goal.id, newValue: 25)
        let xpAfterFirst = vm.user.experience
        let goldAfterFirst = vm.user.gold
        vm.updateManualProgress(goalId: goal.id, newValue: 30)
        #expect(vm.user.experience == xpAfterFirst)
        #expect(vm.user.gold == goldAfterFirst)
    }

    @Test @MainActor func milestone_fitnessGoal_boostsStrength() {
        let vm = makeVM()
        let goal = makeGoal(category: .fitness, targetValue: 100)
        vm.addGoal(goal)
        let base = vm.user.strength
        vm.updateManualProgress(goalId: goal.id, newValue: 25)
        #expect(vm.user.strength == base + 1)
    }

    @Test @MainActor func milestone_wellnessGoal_boostsVitality() {
        let vm = makeVM()
        let goal = makeGoal(category: .wellness, targetValue: 100)
        vm.addGoal(goal)
        let base = vm.user.vitality
        vm.updateManualProgress(goalId: goal.id, newValue: 25)
        #expect(vm.user.vitality == base + 1)
    }

    @Test @MainActor func milestone_learningGoal_boostsIntelligence() {
        let vm = makeVM()
        let goal = makeGoal(category: .learning, targetValue: 100)
        vm.addGoal(goal)
        let base = vm.user.intelligence
        vm.updateManualProgress(goalId: goal.id, newValue: 25)
        #expect(vm.user.intelligence == base + 1)
    }

    @Test @MainActor func milestone_socialGoal_boostsCharisma() {
        let vm = makeVM()
        let goal = makeGoal(category: .social, targetValue: 100)
        vm.addGoal(goal)
        let base = vm.user.charisma
        vm.updateManualProgress(goalId: goal.id, newValue: 25)
        #expect(vm.user.charisma == base + 1)
    }

    @Test @MainActor func milestone_financialGoal_boostsIntelligenceAndCharisma() {
        let vm = makeVM()
        let goal = makeGoal(category: .financial, targetValue: 100)
        vm.addGoal(goal)
        let baseInt = vm.user.intelligence
        let baseCha = vm.user.charisma
        // 25% boost=1: int += 1, cha += 0; 50% boost=2: int += 1, cha += 1 → total int+2, cha+1
        vm.updateManualProgress(goalId: goal.id, newValue: 50)
        #expect(vm.user.intelligence == baseInt + 2)
        #expect(vm.user.charisma == baseCha + 1)
    }

    @Test @MainActor func milestone100_addsTrophyToInventory() {
        let vm = makeVM()
        let goal = makeGoal(targetValue: 100)
        vm.addGoal(goal)
        vm.updateManualProgress(goalId: goal.id, newValue: 100)
        #expect(vm.user.inventory.contains(where: { $0.icon == "trophy.fill" }))
    }

    @Test @MainActor func milestone100_markGoalAsCompleted() {
        let vm = makeVM()
        let goal = makeGoal(targetValue: 100)
        vm.addGoal(goal)
        vm.updateManualProgress(goalId: goal.id, newValue: 100)
        #expect(vm.goals[0].isCompleted == true)
    }

    @Test @MainActor func milestone_setsShowingMilestoneReward() {
        let vm = makeVM()
        let goal = makeGoal(targetValue: 100)
        vm.addGoal(goal)
        vm.updateManualProgress(goalId: goal.id, newValue: 25)
        #expect(vm.showingMilestoneReward == true)
    }

    @Test @MainActor func milestone_setsLastMilestoneMessage() {
        let vm = makeVM()
        let goal = makeGoal(targetValue: 100)
        vm.addGoal(goal)
        vm.updateManualProgress(goalId: goal.id, newValue: 25)
        #expect(vm.lastMilestoneMessage.contains("25%"))
    }
}
