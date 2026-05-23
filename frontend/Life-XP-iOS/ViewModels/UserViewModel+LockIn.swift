import Foundation

extension UserViewModel {
    func startLockIn(habitIDs: [UUID], durationDays: Int) {
        let newChallenge = LockInChallenge(
            habitIDs: habitIDs,
            startDate: Date(),
            durationDays: durationDays
        )
        user.activeLockIn = newChallenge
        uploadToCloud()
    }
}
