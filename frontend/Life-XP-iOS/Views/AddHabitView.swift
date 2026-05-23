import SwiftUI

struct AddHabitView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: UserViewModel

    @State private var title = ""
    @State private var description = ""
    @State private var xpReward = 10
    @State private var category: HabitCategory = .physical
    @State private var enableReminder = false
    @State private var reminderTime = Calendar.current.date(
        bySettingHour: 9, minute: 0, second: 0, of: Date()
    ) ?? Date()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Habit Details")) {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description)
                }

                Section(header: Text("Category")) {
                    Picker("Category", selection: $category) {
                        ForEach(HabitCategory.allCases, id: \.self) { cat in
                            Label(cat.displayName, systemImage: cat.icon).tag(cat)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("Rewards +1 \(category.statBoost.rawValue.capitalized) on completion")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("Reward")) {
                    Stepper("\(xpReward) XP", value: $xpReward, in: 5...100, step: 5)
                }

                Section(header: Text("Reminder")) {
                    Toggle("Daily Reminder", isOn: $enableReminder)
                    if enableReminder {
                        DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                }
            }
            .navigationTitle("New Habit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        viewModel.addHabit(
                            title: title, description: description,
                            experiencePoints: xpReward, category: category,
                            reminderTime: enableReminder ? reminderTime : nil
                        )
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

#Preview {
    AddHabitView(viewModel: .preview)
}
