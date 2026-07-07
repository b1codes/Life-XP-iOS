import Foundation

struct LifeXPUser: Codable {
    var name: String = "Adventurer"
    var level: Int = 1
    var experience: Int = 0
    var gold: Int = 100 // Starting gold

    // Stats
    var strength: Int = 10
    var intelligence: Int = 10
    var vitality: Int = 10
    var charisma: Int = 10

    var inventory: [Item] = []

    // Lock In Mode
    var activeLockIn: LockInChallenge?
    var pastLockIns: [LockInChallenge] = []

    // Tracking sync to avoid double-counting
    var lastSyncedSteps: Int = 0
    var lastSyncedCalories: Double = 0.0
    var lastSyncedSleep: Double = 0.0
    var lastSyncedWater: Double = 0.0
    var lastSyncDate: Date?

    // Threshold calculation
    var xpToNextLevel: Int {
        return level * 100
    }

    var xpProgress: Double {
        return Double(experience) / Double(xpToNextLevel)
    }

    // Reset sync data if it's a new day
    mutating func checkNewDay() {
        guard let lastDate = lastSyncDate else {
            lastSyncDate = Date()
            return
        }

        if !Calendar.current.isDateInToday(lastDate) {
            lastSyncedSteps = 0
            lastSyncedCalories = 0.0
            lastSyncedSleep = 0.0
            lastSyncedWater = 0.0
            lastSyncDate = Date()
        }
    }
}

struct Item: Identifiable, Codable {
    var id = UUID()
    var name: String
    var description: String
    var icon: String
    var price: Int
    var statBoost: StatType?
    var boostAmount: Int = 0
}

enum StatType: String, Codable, CaseIterable {
    case strength, intelligence, vitality, charisma
}

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

enum HabitFrequency: String, Codable, CaseIterable {
    case daily, weekly, custom
}

enum HabitCategory: String, Codable, CaseIterable {
    case physical, mental, social, health

    var icon: String {
        switch self {
        case .physical: return "figure.walk"
        case .mental:   return "brain"
        case .social:   return "person.2.fill"
        case .health:   return "heart.fill"
        }
    }

    var displayName: String { rawValue.capitalized }

    var statBoost: StatType {
        switch self {
        case .physical: return .strength
        case .mental:   return .intelligence
        case .social:   return .charisma
        case .health:   return .vitality
        }
    }
}

struct PublicProfile: Identifiable, Codable {
    var id: String
    var displayName: String
    var level: Int
    var charisma: Int
    var lastUpdated: Date
}

enum GoalCategory: String, Codable, CaseIterable {
    case fitness
    case wellness
    case learning
    case financial
    case social

    var icon: String {
        switch self {
        case .fitness:   return "figure.run"
        case .wellness:  return "heart.fill"
        case .learning:  return "book.fill"
        case .financial: return "banknote.fill"
        case .social:    return "person.2.fill"
        }
    }

    var displayName: String { rawValue.capitalized }
}

enum GoalTrackingType: String, Codable, CaseIterable {
    case manual
    case steps
    case calories

    var displayName: String {
        switch self {
        case .manual:   return "Manual"
        case .steps:    return "Steps (HealthKit)"
        case .calories: return "Calories (HealthKit)"
        }
    }

    var unit: String {
        switch self {
        case .manual:   return ""
        case .steps:    return "steps"
        case .calories: return "kcal"
        }
    }
}

struct Goal: Identifiable, Codable {
    var id = UUID()
    var title: String
    var description: String
    var category: GoalCategory
    var trackingType: GoalTrackingType
    var targetValue: Double
    var currentProgress: Double = 0.0
    var startDate: Date = Date()
    var targetDate: Date?
    var notes: String?
    var photoData: Data?
    var isCompleted: Bool = false
    var awardedMilestones: Set<Int> = []

    var progressFraction: Double {
        guard targetValue > 0 else { return 0 }
        return min(currentProgress / targetValue, 1.0)
    }

    var progressPercent: Int {
        Int(progressFraction * 100)
    }
}

// MARK: - Lock In Mode

enum ChallengeStatus: String, Codable {
    case active, failed, completed
}

struct LockInChallenge: Identifiable, Codable {
    var id = UUID()
    var habitIDs: [UUID]
    var startDate: Date
    var durationDays: Int
    var strikesCount: Int = 0
    var maxStrikes: Int = 3
    var status: ChallengeStatus = .active
    var lastEvaluationDate: Date?

    var endDate: Date {
        Calendar.current.date(byAdding: .day, value: durationDays, to: startDate) ?? startDate
    }
}
