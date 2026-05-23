import Foundation
import UserNotifications

extension UserViewModel {
    func resetBrokenStreaks() {
        let calendar = Calendar.current
        for index in habits.indices {
            guard let lastDate = habits[index].lastCompletedDate else { continue }
            let isRecentlyCompleted = calendar.isDateInToday(lastDate) || calendar.isDateInYesterday(lastDate)
            if !isRecentlyCompleted {
                habits[index].currentStreak = 0
            }
        }
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func scheduleReminder(for habit: Habit) {
        guard let reminderTime = habit.reminderTime else { return }
        cancelReminder(for: habit)

        let content = UNMutableNotificationContent()
        content.title = "Time to \(habit.title)!"
        content.body = habit.currentStreak > 1
            ? "Keep your \(habit.currentStreak)-day streak going!"
            : habit.description
        content.sound = .default

        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: notificationID(for: habit),
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    func cancelReminder(for habit: Habit) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notificationID(for: habit)]
        )
    }

    func scheduleAllReminders() {
        habits.filter { $0.reminderTime != nil }.forEach { scheduleReminder(for: $0) }
    }

    private func notificationID(for habit: Habit) -> String {
        "habit-reminder-\(habit.id.uuidString)"
    }
}
