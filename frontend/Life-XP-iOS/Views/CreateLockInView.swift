import SwiftUI

struct CreateLockInView: View {
    @ObservedObject var viewModel: UserViewModel
    @Environment(\.dismiss) var dismiss

    @State private var selectedHabitIDs: Set<UUID> = []
    @State private var durationDays: Int = 7

    let durations = [7, 14, 30]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select Habits to Lock In")) {
                    if viewModel.habits.isEmpty {
                        Text("No habits found. Create some habits first!")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.habits) { habit in
                            HabitSelectionRow(
                                habit: habit,
                                isSelected: selectedHabitIDs.contains(habit.id)
                            ) {
                                if selectedHabitIDs.contains(habit.id) {
                                    selectedHabitIDs.remove(habit.id)
                                } else {
                                    selectedHabitIDs.insert(habit.id)
                                }
                            }
                        }
                    }
                }

                Section(header: Text("Challenge Duration")) {
                    Picker("Duration", selection: $durationDays) {
                        ForEach(durations, id: \.self) { days in
                            Text("\(days) Days").tag(days)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Lock In Mode Rules", systemImage: "info.circle.fill")
                            .font(.headline)
                            .foregroundColor(.orange)

                        VStack(alignment: .leading, spacing: 8) {
                            RuleRow(
                                icon: "exclamationmark.triangle.fill",
                                text: "All-or-Nothing XP: Rewards are ONLY granted if ALL selected habits are completed every day."
                            )
                            RuleRow(icon: "heart.break.fill", text: "Strike System: Missing a day adds a strike. 3 strikes and the challenge fails!")
                            RuleRow(icon: "trophy.fill", text: "Grand Reward: Complete the challenge for a massive XP boost and a unique trophy.")
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    Button(action: startChallenge) {
                        Text("Start Lock In")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(selectedHabitIDs.isEmpty ? Color.gray : Color.blue)
                    .disabled(selectedHabitIDs.isEmpty)
                }
            }
            .navigationTitle("Lock In Mode")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func startChallenge() {
        let haptic = UIImpactFeedbackGenerator(style: .heavy)
        haptic.impactOccurred()

        viewModel.startLockIn(
            habitIDs: Array(selectedHabitIDs),
            durationDays: durationDays
        )
        dismiss()
    }
}

struct HabitSelectionRow: View {
    let habit: Habit
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: habit.category.icon)
                    .foregroundColor(Color.blue)
                Text(habit.title)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
        }
    }
}

struct RuleRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .font(.system(size: 14))
                .frame(width: 20)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    CreateLockInView(viewModel: .preview)
}
