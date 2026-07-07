import Foundation
import LocalAuthentication
import SwiftUI

extension UserViewModel {
    
    func saveBadHabits() {
        if let encoded = try? JSONEncoder().encode(badHabits) {
            UserDefaults.standard.set(encoded, forKey: "LifeXPBadHabits")
        }
    }
    
    func loadBadHabits() {
        if let data = UserDefaults.standard.data(forKey: "LifeXPBadHabits"),
           let decoded = try? JSONDecoder().decode([BadHabit].self, from: data) {
            badHabits = decoded
        } else {
            // Default sample bad habits
            let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
            let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            
            let socialMedia = BadHabit(
                title: "Doomscrolling",
                category: .socialMedia,
                whyNote: "To be more productive and present with family",
                startDate: threeDaysAgo,
                records: [
                    BadHabitRecord(date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!, status: .clean),
                    BadHabitRecord(date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, status: .clean)
                ]
            )
            
            let junkFood = BadHabit(
                title: "Soda & Candy",
                category: .junkFood,
                whyNote: "To improve my physical health and energy levels",
                startDate: oneDayAgo
            )
            
            badHabits = [socialMedia, junkFood]
        }
    }
    
    func addBadHabit(title: String, category: BadHabitCategory, customCategoryName: String?, whyNote: String?, startDate: Date) {
        let newHabit = BadHabit(
            title: title,
            category: category,
            customCategoryName: customCategoryName,
            whyNote: whyNote,
            startDate: startDate
        )
        badHabits.append(newHabit)
        saveBadHabits()
        uploadToCloud()
    }
    
    func deleteBadHabit(at offsets: IndexSet) {
        badHabits.remove(atOffsets: offsets)
        saveBadHabits()
        uploadToCloud()
    }
    
    func logCleanDay(for badHabit: BadHabit) {
        guard let index = badHabits.firstIndex(where: { $0.id == badHabit.id }) else { return }
        
        let today = Date()
        let calendar = Calendar.current
        
        // Check if already logged today
        if badHabits[index].records.contains(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
            return
        }
        
        let record = BadHabitRecord(date: today, status: .clean)
        badHabits[index].records.append(record)
        
        // Update longest streak if current streak exceeds it
        let currentStreak = badHabits[index].currentStreakInDays
        
        // If they beat their personal record, give them an XP bonus!
        if currentStreak > badHabits[index].longestStreak {
            if badHabits[index].longestStreak > 0 {
                // Award beat-PB bonus
                addExperience(20)
                lastMilestoneMessage = "New Personal Best for \(badHabit.displayName)! +20 XP!"
                showingMilestoneReward = true
            }
            badHabits[index].longestStreak = currentStreak
        }
        
        // Check for milestones
        checkBadHabitMilestones(for: &badHabits[index])
        
        saveBadHabits()
        uploadToCloud()
    }
    
    func logRelapse(for badHabit: BadHabit, note: String?) {
        guard let index = badHabits.firstIndex(where: { $0.id == badHabit.id }) else { return }
        
        let today = Date()
        let record = BadHabitRecord(date: today, status: .relapse, note: note)
        
        // Update longest streak before resetting current streak
        let currentStreak = badHabits[index].currentStreakInDays
        if currentStreak > badHabits[index].longestStreak {
            badHabits[index].longestStreak = currentStreak
        }
        
        // Reset current streak milestones so they can earn them again on the next clean run
        badHabits[index].currentStreakMilestonesAwarded = []
        badHabits[index].records.append(record)
        
        // Award honest relapse logging XP ("recovery XP")
        let recoveryXPReward = 10
        addExperience(recoveryXPReward)
        
        lastMilestoneMessage = "Honest log! Resetting streak for \(badHabit.displayName). +\(recoveryXPReward) Recovery XP. Stay strong, you can do this!"
        showingMilestoneReward = true
        
        saveBadHabits()
        uploadToCloud()
    }
    
    private func checkBadHabitMilestones(for badHabit: inout BadHabit) {
        let currentDays = badHabit.currentStreakInDays
        let milestones = [
            1: 10,       // 1 day: 10 XP
            3: 25,       // 3 days: 25 XP
            7: 50,       // 1 week: 50 XP
            14: 100,     // 2 weeks: 100 XP
            30: 250,     // 1 month: 250 XP
            90: 500,     // 3 months: 500 XP
            180: 1000,   // 6 months: 1000 XP
            365: 2500    // 1 year: 2500 XP
        ]
        
        for (dayCount, xpAmount) in milestones {
            if currentDays >= dayCount && !badHabit.currentStreakMilestonesAwarded.contains(dayCount) {
                badHabit.currentStreakMilestonesAwarded.insert(dayCount)
                addExperience(xpAmount)
                
                let dayWord = dayCount == 1 ? "day" : "days"
                lastMilestoneMessage = "Milestone achieved! \(badHabit.displayName) clean for \(dayCount) \(dayWord)! +\(xpAmount) XP!"
                showingMilestoneReward = true
            }
        }
    }
    
    // MARK: - Biometric Security
    
    func authenticateBreakItSection(completion: @escaping (Bool) -> Void) {
        guard requireBiometricLock else {
            self.isBreakItUnlocked = true
            completion(true)
            return
        }
        
        let context = LAContext()
        var error: NSError?
        
        // Use deviceOwnerAuthentication for passcode fallback automatically
        let policy: LAPolicy = .deviceOwnerAuthentication
        
        if context.canEvaluatePolicy(policy, error: &error) {
            let reason = "Authenticate to access the Break It section."
            context.evaluatePolicy(policy, localizedReason: reason) { success, authError in
                DispatchQueue.main.async {
                    if success {
                        self.isBreakItUnlocked = true
                    }
                    completion(success)
                }
            }
        } else {
            // No biometric auth hardware/enrolled, default fallback to passcode
            DispatchQueue.main.async {
                // If passcode or biometrics are not set up at all, allow access or return false.
                // The prompt specified "Graceful passcode fallback when biometrics unavailable or fail 3 times."
                // In simulator or device without passcode/biometrics, we will return false to show the fallback screen.
                completion(false)
            }
        }
    }
    
    func setBiometricLock(_ enabled: Bool, completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        let policy: LAPolicy = .deviceOwnerAuthentication
        
        if context.canEvaluatePolicy(policy, error: &error) {
            let reason = enabled ? "Verify to enable biometric lock." : "Verify to disable biometric lock."
            context.evaluatePolicy(policy, localizedReason: reason) { success, authError in
                DispatchQueue.main.async {
                    if success {
                        UserDefaults.standard.set(enabled, forKey: "RequireBiometricLock")
                        self.requireBiometricLock = enabled
                        if enabled {
                            self.isBreakItUnlocked = false
                        } else {
                            self.isBreakItUnlocked = true
                        }
                    }
                    completion(success)
                }
            }
        } else {
            DispatchQueue.main.async {
                completion(false)
            }
        }
    }
}
