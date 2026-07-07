import SwiftUI

struct BreakItView: View {
    @ObservedObject var viewModel: UserViewModel
    @Environment(\.scenePhase) var scenePhase
    @State private var showingAddHabit = false
    @State private var selectedHabitForRelapse: BadHabit?

    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.requireBiometricLock && !viewModel.isBreakItUnlocked {
                    BreakItLockScreen {
                        viewModel.authenticateBreakItSection { _ in }
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Summary Stats Card
                            summaryStatsCard
                            
                            // Vices List
                            if viewModel.badHabits.isEmpty {
                                emptyStateView
                            } else {
                                ForEach(viewModel.badHabits) { habit in
                                    BadHabitCard(
                                        habit: habit,
                                        onClean: {
                                            viewModel.logCleanDay(for: habit)
                                        },
                                        onRelapse: {
                                            selectedHabitForRelapse = habit
                                        }
                                    )
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.top)
                    }
                    .background(Color(.systemGroupedBackground))
                    .blur(radius: (viewModel.requireBiometricLock && scenePhase != .active) ? 20 : 0)
                }

                // Privacy Switcher Shield
                if viewModel.requireBiometricLock && scenePhase != .active {
                    Color(.systemBackground)
                        .opacity(0.98)
                        .overlay(
                            VStack(spacing: 15) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 70))
                                    .foregroundColor(.blue)
                                Text("Privacy Shield Active")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Text("Content is hidden in app switcher.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        )
                        .edgesIgnoringSafeArea(.all)
                }
            }
            .navigationTitle("Break It")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddHabit.toggle() }) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                    }
                }
            }
            .sheet(isPresented: $showingAddHabit) {
                AddBadHabitView(viewModel: viewModel)
            }
            .sheet(item: $selectedHabitForRelapse) { habit in
                RelapseLogView(viewModel: viewModel, habit: habit)
            }
            .alert(viewModel.lastMilestoneMessage, isPresented: $viewModel.showingMilestoneReward) {
                Button("Awesome!", role: .cancel) {}
            }
            .onAppear {
                if viewModel.requireBiometricLock && !viewModel.isBreakItUnlocked {
                    viewModel.authenticateBreakItSection { _ in }
                }
            }
        }
    }

    private var summaryStatsCard: some View {
        VStack(spacing: 15) {
            Text("Recover Journey")
                .font(.headline)
                .foregroundColor(.secondary)

            HStack(spacing: 25) {
                StatItem(
                    value: "\(viewModel.badHabits.count)",
                    label: "Active Vices"
                )
                
                Divider()
                    .frame(height: 40)

                StatItem(
                    value: "\(totalCleanDaysCount)",
                    label: "Clean Days"
                )
                
                Divider()
                    .frame(height: 40)

                StatItem(
                    value: "\(bestStreakAcrossAll)",
                    label: "Best Streak"
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .llcGlass()
        .padding(.horizontal)
    }

    private var totalCleanDaysCount: Int {
        viewModel.badHabits.reduce(0) { total, habit in
            total + habit.records.filter { $0.status == .clean }.count
        }
    }

    private var bestStreakAcrossAll: Int {
        viewModel.badHabits.reduce(0) { maxStreak, habit in
            max(maxStreak, habit.longestStreak)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.broken.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.6))
                .padding(.top, 40)

            Text("No habits to break yet!")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.secondary)

            Text("Tackling vices is just as important as building good habits. Tap '+' to start tracking and accountability.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: { showingAddHabit.toggle() }) {
                Text("Add Your First Vice")
                    .fontWeight(.semibold)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top, 10)
        }
    }
}

struct StatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct BreakItLockScreen: View {
    let onUnlock: () -> Void

    var body: some View {
        VStack(spacing: 25) {
            Spacer()
            
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
            
            Text("Break It Locked")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Authentication required to view sensitive habits.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 50)
            
            Button(action: onUnlock) {
                HStack(spacing: 8) {
                    Image(systemName: "faceid")
                    Text("Unlock Section")
                }
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.blue)
                )
            }
            .padding(.horizontal, 40)
            .padding(.top, 15)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

struct BadHabitCard: View {
    let habit: BadHabit
    let onClean: () -> Void
    let onRelapse: () -> Void

    private var categoryColor: Color {
        switch habit.category {
        case .smoking: return .secondary
        case .alcohol: return .purple
        case .socialMedia: return .blue
        case .junkFood: return .orange
        case .repetitive: return .pink
        case .gambling: return .red
        case .custom: return .indigo
        }
    }

    private var todayIsLogged: Bool {
        let calendar = Calendar.current
        return habit.records.contains { calendar.isDateInToday($0.date) }
    }

    private var todayIsRelapse: Bool {
        let calendar = Calendar.current
        return habit.records.contains { calendar.isDateInToday($0.date) && $0.status == .relapse }
    }

    private var todayIsClean: Bool {
        let calendar = Calendar.current
        return habit.records.contains { calendar.isDateInToday($0.date) && $0.status == .clean }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Header
            HStack(alignment: .top) {
                Image(systemName: habit.category.icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(categoryColor)
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.title)
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text(habit.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(categoryColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(categoryColor.opacity(0.15))
                        .cornerRadius(6)
                }

                Spacer()
                
                // Streaks Column
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Streak")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(habit.streakDisplayText)
                        .font(.headline)
                        .fontWeight(.heavy)
                        .foregroundColor(todayIsRelapse ? .red : .green)
                    
                    Text("PB: \(habit.longestStreak)d")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }

            // Why Motivation Note
            if let why = habit.whyNote, !why.isEmpty {
                Text("\"\(why)\"")
                    .font(.caption)
                    .italic()
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
            }

            // Heatmap Grid
            CalendarHeatmapView(habit: habit, onMarkClean: { date in
                // Dynamic clean day log helper (though currently we expose today mostly)
                // In our model we allow marking clean
            })

            // Actions
            HStack(spacing: 12) {
                Button(action: onClean) {
                    HStack {
                        Image(systemName: todayIsClean ? "checkmark.circle.fill" : "checkmark")
                        Text(todayIsClean ? "Clean Today!" : "Stayed Clean")
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(todayIsClean ? .green : .white)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        todayIsClean
                            ? Color.green.opacity(0.15)
                            : (todayIsLogged ? Color.gray : Color.blue)
                    )
                    .cornerRadius(10)
                }
                .disabled(todayIsLogged)

                Button(action: onRelapse) {
                    HStack {
                        Image(systemName: todayIsRelapse ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                        Text(todayIsRelapse ? "Relapsed" : "Log Relapse")
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(todayIsRelapse ? .white : .red)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        todayIsRelapse
                            ? Color.red
                            : Color.red.opacity(0.15)
                    )
                    .cornerRadius(10)
                }
                .disabled(todayIsRelapse)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

struct CalendarHeatmapView: View {
    let habit: BadHabit
    let onMarkClean: (Date) -> Void

    private var daysInMonth: [Date] {
        let calendar = Calendar.current
        let now = Date()
        guard let monthRange = calendar.range(of: .day, in: .month, for: now),
              let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return []
        }

        return monthRange.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)
        }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(currentMonthYearString)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)

            LazyVGrid(columns: columns, spacing: 4) {
                // Header Weekdays
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.8))
                        .frame(maxWidth: .infinity)
                }

                // Month Start Padding
                ForEach(0..<firstWeekdayPadding, id: \.self) { _ in
                    Color.clear
                        .frame(height: 18)
                }

                // Days
                ForEach(daysInMonth, id: \.self) { date in
                    let record = habit.records.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
                    let isToday = Calendar.current.isDateInToday(date)
                    let isFuture = date > Date()
                    let isBeforeStart = Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: habit.startDate)

                    let color: Color = {
                        if isFuture {
                            return Color.clear
                        } else if let rec = record {
                            return rec.status == .clean ? .green.opacity(0.8) : .red.opacity(0.8)
                        } else if isBeforeStart {
                            return Color(.systemGray6)
                        } else {
                            return Color(.systemGray5)
                        }
                    }()

                    let textColor: Color = {
                        if isFuture {
                            return .secondary.opacity(0.3)
                        } else if record != nil {
                            return .white
                        } else if isToday {
                            return .blue
                        } else {
                            return .primary
                        }
                    }()

                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: 9, weight: isToday ? .bold : .regular))
                        .foregroundColor(textColor)
                        .frame(height: 18)
                        .frame(maxWidth: .infinity)
                        .background(color)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(isToday ? Color.blue : Color.clear, lineWidth: 1)
                        )
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(10)
    }

    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        return formatter.veryShortStandaloneWeekdaySymbols
    }

    private var firstWeekdayPadding: Int {
        guard let firstDay = daysInMonth.first else { return 0 }
        return Calendar.current.component(.weekday, from: firstDay) - 1
    }

    private var currentMonthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }
}
