import Testing
import Foundation
@testable import Life_XP_iOS

@Suite("Lock In Models")
struct LockInModelTests {
    @Test func challengeModel_initializesCorrectly() {
        let id = UUID()
        let habitIDs = [UUID(), UUID()]
        let startDate = Date()
        let challenge = LockInChallenge(
            id: id,
            habitIDs: habitIDs,
            startDate: startDate,
            durationDays: 7
        )
        #expect(challenge.status == .active)
        #expect(challenge.strikesCount == 0)
        #expect(challenge.maxStrikes == 3)
    }
}

@Suite("Lock In Logic")
struct LockInLogicTests {
    @MainActor private func makeVM() -> UserViewModel {
        let vm = UserViewModel(skipCloudSync: true)
        vm.user = LifeXPUser()
        vm.habits = [
            Habit(title: "H1", description: "", xpReward: 100, frequency: .daily),
            Habit(title: "H2", description: "", xpReward: 100, frequency: .daily)
        ]
        return vm
    }

    @Test @MainActor func completeHabit_doesNotAwardXP_ifInActiveLockIn() {
        let vm = makeVM()
        let habit = vm.habits[0]
        vm.user.activeLockIn = LockInChallenge(habitIDs: [habit.id], startDate: Date(), durationDays: 7)

        vm.completeHabit(habit)

        #expect(vm.user.experience == 0) // Should be deferred
    }

    @Test @MainActor func evaluateLockIn_completesChallenge_ifEndDateReached() {
        let vm = UserViewModel(skipCloudSync: true)
        vm.user = LifeXPUser()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        vm.user.activeLockIn = LockInChallenge(habitIDs: [], startDate: startDate, durationDays: 7)

        vm.evaluateLockIn()

        #expect(vm.user.activeLockIn == nil)
        #expect(vm.user.pastLockIns.last?.status == .completed)
        #expect(vm.user.inventory.contains(where: { $0.icon == "lock.shield.fill" }))
        #expect(vm.showingLockInReward == true)
    }
}
