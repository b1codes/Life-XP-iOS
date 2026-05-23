import Foundation

extension LifeXPUser {
    static let preview = LifeXPUser(
        name: "Epic Adventurer",
        level: 5,
        experience: 250,
        strength: 15,
        intelligence: 12,
        vitality: 18,
        charisma: 10,
        lastSyncedSteps: 5000,
        lastSyncedCalories: 300.0,
        lastSyncedSleep: 7.5,
        lastSyncedWater: 1.5,
        lastSyncDate: Date()
    )
}

extension Habit {
    static let previewHabits = [
        Habit(title: "Hydrate", description: "Drink 2L of water",
              xpReward: 20, frequency: .daily, category: .health),
        Habit(title: "Morning Sprint", description: "Fast jog for 15m",
              xpReward: 40, frequency: .daily, category: .physical, lastCompletedDate: Date()),
        Habit(title: "Meditation", description: "10m mindfulness",
              xpReward: 15, frequency: .daily, category: .mental),
        Habit(title: "Call a Friend", description: "Stay connected",
              xpReward: 25, frequency: .daily, category: .social)
    ]
}

extension Goal {
    static let previewGoals: [Goal] = {
        var fitness = Goal(
            title: "Run 100 Miles",
            description: "Cumulative running goal for the year",
            category: .fitness,
            trackingType: .steps,
            targetValue: 200_000
        )
        fitness.currentProgress = 87_500

        var wellness = Goal(
            title: "Sleep Better",
            description: "Improve sleep consistency",
            category: .wellness,
            trackingType: .manual,
            targetValue: 30
        )
        wellness.currentProgress = 22
        wellness.awardedMilestones = [25, 50]

        var learning = Goal(
            title: "Read 12 Books",
            description: "One book per month",
            category: .learning,
            trackingType: .manual,
            targetValue: 12
        )
        learning.currentProgress = 3

        return [fitness, wellness, learning]
    }()
}

extension PublicProfile {
    static let previewLeaderboard: [PublicProfile] = [
        PublicProfile(id: "preview-1", displayName: "DragonSlayer99", level: 12, charisma: 28, lastUpdated: Date()),
        PublicProfile(id: "preview-2", displayName: "Epic Adventurer", level: 5, charisma: 10, lastUpdated: Date()),
        PublicProfile(id: "preview-3", displayName: "NightWatcher", level: 4, charisma: 14, lastUpdated: Date()),
        PublicProfile(id: "preview-4", displayName: "SwiftCoder", level: 3, charisma: 11, lastUpdated: Date())
    ]
}

extension UserViewModel {
    static var preview: UserViewModel {
        let previewVM = UserViewModel(skipCloudSync: true)
        previewVM.user = .preview
        previewVM.habits = Habit.previewHabits
        previewVM.goals = Goal.previewGoals
        previewVM.leaderboard = PublicProfile.previewLeaderboard
        return previewVM
    }
}
