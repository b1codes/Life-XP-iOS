import Foundation

enum BadHabitCategory: String, Codable, CaseIterable {
    case smoking
    case alcohol
    case socialMedia
    case junkFood
    case repetitive
    case gambling
    case custom

    var displayName: String {
        switch self {
        case .smoking: return "Smoking / Vaping"
        case .alcohol: return "Alcohol"
        case .socialMedia: return "Social Media Over-use"
        case .junkFood: return "Junk Food / Sugar"
        case .repetitive: return "Body-focused (Nail biting, etc.)"
        case .gambling: return "Gambling"
        case .custom: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .smoking: return "wind"
        case .alcohol: return "wineglass.fill"
        case .socialMedia: return "iphone"
        case .junkFood: return "birthday.cake.fill"
        case .repetitive: return "hand.raised.fill"
        case .gambling: return "suit.spade.fill"
        case .custom: return "ellipsis.circle"
        }
    }
}

enum BadHabitRecordStatus: String, Codable {
    case clean
    case relapse
}

struct BadHabitRecord: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var status: BadHabitRecordStatus
    var note: String? // Optional note on what triggered a relapse
}

struct BadHabit: Identifiable, Codable {
    var id = UUID()
    var title: String
    var category: BadHabitCategory
    var customCategoryName: String?
    var whyNote: String?
    var startDate: Date
    var records: [BadHabitRecord] = []
    var longestStreak: Int = 0 // In days
    var currentStreakMilestonesAwarded: Set<Int> = []

    var displayName: String {
        if category == .custom, let customName = customCategoryName, !customName.isEmpty {
            return customName
        }
        return category.displayName
    }

    // Start of the current clean period (either start date, or date of the last relapse)
    var cleanPeriodStart: Date {
        let relapses = records.filter { $0.status == .relapse }.sorted { $0.date > $1.date }
        return relapses.first?.date ?? startDate
    }

    var currentStreakInHours: Int {
        let duration = Date().timeIntervalSince(cleanPeriodStart)
        return max(0, Int(duration / 3600))
    }

    var currentStreakInDays: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.startOfDay(for: cleanPeriodStart)

        // If the last relapse was today, streak is 0
        let relapses = records.filter { $0.status == .relapse }
        if let lastRelapse = relapses.max(by: { $0.date < $1.date }), calendar.isDateInToday(lastRelapse.date) {
            return 0
        }

        let diff = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        return max(0, diff)
    }

    var streakDisplayText: String {
        let hours = currentStreakInHours
        if hours < 48 {
            return "\(hours) \(hours == 1 ? "hour" : "hours")"
        } else {
            let days = currentStreakInDays
            return "\(days) \(days == 1 ? "day" : "days")"
        }
    }
}
