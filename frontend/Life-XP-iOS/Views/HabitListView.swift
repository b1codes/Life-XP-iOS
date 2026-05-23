import SwiftUI

private func categoryColor(_ category: HabitCategory) -> Color {
    switch category {
    case .physical: return .red
    case .mental:   return .purple
    case .social:   return .orange
    case .health:   return .green
    }
}

struct HabitListView: View {
    @ObservedObject var viewModel: UserViewModel
    @State private var showingAddHabit = false
    @State private var showingLockInView = false

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Your Daily Habits")) {
                    ForEach(viewModel.habits) { habit in
                        HabitRowView(habit: habit, onComplete: {
                            viewModel.completeHabit(habit)
                        })
                    }
                    .onDelete(perform: viewModel.deleteHabit)
                }
            }
            .navigationTitle("Habits")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.user.activeLockIn == nil {
                        Button(action: {
                            showingLockInView.toggle()
                        }, label: {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.shield.fill")
                                Text("Lock In")
                            }
                            .font(.subheadline)
                            .fontWeight(.bold)
                        })
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddHabit.toggle()
                    }, label: {
                        Image(systemName: "plus")
                    })
                }
            }
            .sheet(isPresented: $showingAddHabit) {
                AddHabitView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingLockInView) {
                CreateLockInView(viewModel: viewModel)
            }
        }
    }
}

struct HabitRowView: View {
    let habit: Habit
    let onComplete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: habit.category.icon)
                        .foregroundColor(categoryColor(habit.category))
                        .font(.system(size: 11))
                    Text(habit.title)
                        .font(.headline)
                        .strikethrough(habit.isCompletedToday, color: .secondary)
                }
                Text(habit.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 10))
                        Text("\(habit.xpReward) XP")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    if habit.currentStreak > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(habit.currentStreak >= 7 ? .red : .orange)
                                .font(.system(size: 10))
                            Text("\(habit.currentStreak)d")
                                .font(.caption2)
                                .foregroundColor(habit.currentStreak >= 7 ? .red : .orange)
                                .fontWeight(habit.currentStreak >= 7 ? .bold : .regular)
                        }
                    }
                    if habit.reminderTime != nil {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 9))
                    }
                }
            }

            Spacer()

            Button(action: onComplete) {
                Image(systemName: habit.isCompletedToday ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(habit.isCompletedToday ? .green : .blue)
                    .font(.title2)
            }
            .disabled(habit.isCompletedToday)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HabitListView(viewModel: .preview)
}
