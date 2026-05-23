import Foundation
import CloudKit

class CloudKitManager {
    static let shared = CloudKitManager()

    lazy var container = CKContainer.default()
    lazy var privateDatabase = container.privateCloudDatabase

    // User Record Type
    let userRecordType = "UserStats"
    let habitRecordType = "Habit"

    func saveUserStats(_ user: LifeXPUser, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        let recordID = CKRecord.ID(recordName: "DefaultUserStats")

        privateDatabase.fetch(withRecordID: recordID) { record, _ in
            let userRecord = record ?? CKRecord(recordType: self.userRecordType, recordID: recordID)

            userRecord["name"] = user.name as CKRecordValue
            userRecord["level"] = user.level as CKRecordValue
            userRecord["experience"] = user.experience as CKRecordValue
            userRecord["strength"] = user.strength as CKRecordValue
            userRecord["intelligence"] = user.intelligence as CKRecordValue
            userRecord["vitality"] = user.vitality as CKRecordValue
            userRecord["charisma"] = user.charisma as CKRecordValue
            userRecord["lastSyncedSteps"] = user.lastSyncedSteps as CKRecordValue
            userRecord["lastSyncedCalories"] = user.lastSyncedCalories as CKRecordValue
            userRecord["lastSyncedSleep"] = user.lastSyncedSleep as CKRecordValue
            userRecord["lastSyncedWater"] = user.lastSyncedWater as CKRecordValue

            self.privateDatabase.save(userRecord) { (savedRecord, saveError) in
                if let saveError = saveError {
                    completion(.failure(saveError))
                } else if let savedRecord = savedRecord {
                    completion(.success(savedRecord))
                }
            }
        }
    }

    func fetchUserStats(completion: @escaping (Result<LifeXPUser, Error>) -> Void) {
        let recordID = CKRecord.ID(recordName: "DefaultUserStats")

        privateDatabase.fetch(withRecordID: recordID) { (record, error) in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let record = record else {
                let error = NSError(
                    domain: "CloudKitManager",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "No user record found"]
                )
                completion(.failure(error))
                return
            }

            var user = LifeXPUser()
            user.name = record["name"] as? String ?? "Adventurer"
            user.level = record["level"] as? Int ?? 1
            user.experience = record["experience"] as? Int ?? 0
            user.strength = record["strength"] as? Int ?? 10
            user.intelligence = record["intelligence"] as? Int ?? 10
            user.vitality = record["vitality"] as? Int ?? 10
            user.charisma = record["charisma"] as? Int ?? 10
            user.lastSyncedSteps = record["lastSyncedSteps"] as? Int ?? 0
            user.lastSyncedCalories = record["lastSyncedCalories"] as? Double ?? 0.0
            user.lastSyncedSleep = record["lastSyncedSleep"] as? Double ?? 0.0
            user.lastSyncedWater = record["lastSyncedWater"] as? Double ?? 0.0

            completion(.success(user))
        }
    }

    func saveHabits(_ habits: [Habit], completion: @escaping (Error?) -> Void) {
        // Delete old habits first (simple approach for MVP)
        let query = CKQuery(recordType: habitRecordType, predicate: NSPredicate(value: true))

        privateDatabase.perform(query, inZoneWith: nil) { records, _ in
            let deleteIDs = records?.map { $0.recordID } ?? []
            let deleteOperation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: deleteIDs)

            deleteOperation.modifyRecordsCompletionBlock = { (_, _, deleteError) in
                if let deleteError = deleteError {
                    completion(deleteError)
                    return
                }

                let recordsToSave = habits.map { habit -> CKRecord in
                    let record = CKRecord(recordType: self.habitRecordType)
                    record["title"] = habit.title as CKRecordValue
                    record["description"] = habit.description as CKRecordValue
                    record["xpReward"] = habit.xpReward as CKRecordValue
                    record["frequency"] = habit.frequency.rawValue as CKRecordValue
                    record["category"] = habit.category.rawValue as CKRecordValue
                    record["currentStreak"] = habit.currentStreak as CKRecordValue
                    record["longestStreak"] = habit.longestStreak as CKRecordValue
                    if let lastDate = habit.lastCompletedDate {
                        record["lastCompletedDate"] = lastDate as CKRecordValue
                    }
                    if let reminderTime = habit.reminderTime {
                        record["reminderTime"] = reminderTime as CKRecordValue
                    }
                    return record
                }

                let saveOperation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: nil)
                saveOperation.modifyRecordsCompletionBlock = { (_, _, saveError) in
                    completion(saveError)
                }
                self.privateDatabase.add(saveOperation)
            }
            self.privateDatabase.add(deleteOperation)
        }
    }

    func fetchHabits(completion: @escaping (Result<[Habit], Error>) -> Void) {
        let query = CKQuery(recordType: habitRecordType, predicate: NSPredicate(value: true))

        privateDatabase.perform(query, inZoneWith: nil) { (records, error) in
            if let error = error {
                completion(.failure(error))
                return
            }

            let habits = records?.compactMap { record -> Habit? in
                guard let title = record["title"] as? String,
                      let description = record["description"] as? String,
                      let xpReward = record["xpReward"] as? Int,
                      let frequencyString = record["frequency"] as? String,
                      let frequency = HabitFrequency(rawValue: frequencyString) else {
                    return nil
                }

                var habit = Habit(title: title, description: description, xpReward: xpReward, frequency: frequency)
                habit.lastCompletedDate = record["lastCompletedDate"] as? Date
                habit.currentStreak = record["currentStreak"] as? Int ?? 0
                habit.longestStreak = record["longestStreak"] as? Int ?? 0
                habit.reminderTime = record["reminderTime"] as? Date
                if let categoryString = record["category"] as? String,
                   let category = HabitCategory(rawValue: categoryString) {
                    habit.category = category
                }
                return habit
            } ?? []

            completion(.success(habits))
        }
    }
}

// MARK: - Public Leaderboard

extension CloudKitManager {
    private var publicDatabase: CKDatabase { container.publicCloudDatabase }
    private var publicProfileRecordType: String { "PublicProfile" }

    func savePublicProfile(recordName: String, name: String, level: Int, charisma: Int,
                           completion: @escaping (Error?) -> Void) {
        let recordID = CKRecord.ID(recordName: recordName)
        publicDatabase.fetch(withRecordID: recordID) { record, _ in
            let profileRecord = record ?? CKRecord(recordType: self.publicProfileRecordType, recordID: recordID)
            profileRecord["displayName"] = name as CKRecordValue
            profileRecord["level"] = level as CKRecordValue
            profileRecord["charisma"] = charisma as CKRecordValue
            profileRecord["lastUpdated"] = Date() as CKRecordValue
            self.publicDatabase.save(profileRecord) { _, error in completion(error) }
        }
    }

    func fetchLeaderboard(limit: Int = 20, completion: @escaping (Result<[PublicProfile], Error>) -> Void) {
        let query = CKQuery(recordType: publicProfileRecordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "level", ascending: false)]
        publicDatabase.perform(query, inZoneWith: nil) { records, error in
            if let error = error { completion(.failure(error)); return }
            let profiles = (records ?? []).prefix(limit).compactMap { record -> PublicProfile? in
                guard let name = record["displayName"] as? String,
                      let level = record["level"] as? Int,
                      let charisma = record["charisma"] as? Int,
                      let lastUpdated = record["lastUpdated"] as? Date else { return nil }
                return PublicProfile(id: record.recordID.recordName, displayName: name,
                                    level: level, charisma: charisma, lastUpdated: lastUpdated)
            }
            completion(.success(Array(profiles)))
        }
    }
}

// MARK: - Goal Sync

extension CloudKitManager {
    private var goalRecordType: String { "Goal" }

    func saveGoals(_ goals: [Goal], completion: @escaping (Error?) -> Void) {
        let query = CKQuery(recordType: goalRecordType, predicate: NSPredicate(value: true))

        privateDatabase.perform(query, inZoneWith: nil) { records, _ in
            let deleteIDs = records?.map { $0.recordID } ?? []
            let deleteOperation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: deleteIDs)

            deleteOperation.modifyRecordsCompletionBlock = { _, _, deleteError in
                if let deleteError = deleteError { completion(deleteError); return }

                let recordsToSave: [CKRecord] = goals.map { goal in
                    let record = CKRecord(recordType: self.goalRecordType)
                    record["goalId"] = goal.id.uuidString as CKRecordValue
                    record["title"] = goal.title as CKRecordValue
                    record["goalDescription"] = goal.description as CKRecordValue
                    record["category"] = goal.category.rawValue as CKRecordValue
                    record["trackingType"] = goal.trackingType.rawValue as CKRecordValue
                    record["targetValue"] = goal.targetValue as CKRecordValue
                    record["currentProgress"] = goal.currentProgress as CKRecordValue
                    record["startDate"] = goal.startDate as CKRecordValue
                    record["isCompleted"] = (goal.isCompleted ? 1 : 0) as CKRecordValue
                    if let targetDate = goal.targetDate { record["targetDate"] = targetDate as CKRecordValue }
                    if let notes = goal.notes { record["notes"] = notes as CKRecordValue }
                    if let data = try? JSONEncoder().encode(Array(goal.awardedMilestones)),
                       let jsonString = String(data: data, encoding: .utf8) {
                        record["awardedMilestones"] = jsonString as CKRecordValue
                    }
                    return record
                }

                let saveOperation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: nil)
                saveOperation.modifyRecordsCompletionBlock = { _, _, saveError in completion(saveError) }
                self.privateDatabase.add(saveOperation)
            }
            self.privateDatabase.add(deleteOperation)
        }
    }

    func fetchGoals(completion: @escaping (Result<[Goal], Error>) -> Void) {
        let query = CKQuery(recordType: goalRecordType, predicate: NSPredicate(value: true))

        privateDatabase.perform(query, inZoneWith: nil) { records, error in
            if let error = error { completion(.failure(error)); return }

            let goals: [Goal] = records?.compactMap { record in
                guard
                    let idString = record["goalId"] as? String,
                    let id = UUID(uuidString: idString),
                    let title = record["title"] as? String,
                    let description = record["goalDescription"] as? String,
                    let categoryString = record["category"] as? String,
                    let category = GoalCategory(rawValue: categoryString),
                    let trackingTypeString = record["trackingType"] as? String,
                    let trackingType = GoalTrackingType(rawValue: trackingTypeString),
                    let targetValue = record["targetValue"] as? Double,
                    let currentProgress = record["currentProgress"] as? Double,
                    let startDate = record["startDate"] as? Date
                else { return nil }

                var goal = Goal(title: title, description: description, category: category,
                                trackingType: trackingType, targetValue: targetValue)
                goal.id = id
                goal.currentProgress = currentProgress
                goal.startDate = startDate
                goal.targetDate = record["targetDate"] as? Date
                goal.notes = record["notes"] as? String
                goal.isCompleted = (record["isCompleted"] as? Int ?? 0) == 1
                if let jsonString = record["awardedMilestones"] as? String,
                   let data = jsonString.data(using: .utf8),
                   let array = try? JSONDecoder().decode([Int].self, from: data) {
                    goal.awardedMilestones = Set(array)
                }
                return goal
            } ?? []

            completion(.success(goals))
        }
    }
}
