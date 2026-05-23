import SwiftUI

struct GoalsView: View {
    @ObservedObject var viewModel: UserViewModel
    @State private var showingAddGoal = false

    var body: some View {
        NavigationView {
            Group {
                if viewModel.goals.isEmpty {
                    GoalsEmptyStateView()
                } else {
                    List {
                        let active = viewModel.goals.filter { !$0.isCompleted }
                        let completed = viewModel.goals.filter { $0.isCompleted }

                        if !active.isEmpty {
                            Section(header: Text("Active Goals")) {
                                ForEach(active) { goal in
                                    NavigationLink(destination: GoalDetailView(viewModel: viewModel, goal: goal)) {
                                        GoalRowView(goal: goal)
                                    }
                                }
                                .onDelete { offsets in
                                    let ids = offsets.map { active[$0].id }
                                    for id in ids {
                                        if let idx = viewModel.goals.firstIndex(where: { $0.id == id }) {
                                            viewModel.deleteGoal(at: IndexSet(integer: idx))
                                        }
                                    }
                                }
                            }
                        }

                        if !completed.isEmpty {
                            Section(header: Text("Completed")) {
                                ForEach(completed) { goal in
                                    NavigationLink(destination: GoalDetailView(viewModel: viewModel, goal: goal)) {
                                        GoalRowView(goal: goal)
                                    }
                                }
                                .onDelete { offsets in
                                    let ids = offsets.map { completed[$0].id }
                                    for id in ids {
                                        if let idx = viewModel.goals.firstIndex(where: { $0.id == id }) {
                                            viewModel.deleteGoal(at: IndexSet(integer: idx))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Goals")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddGoal.toggle() }, label: {
                        Image(systemName: "plus")
                    })
                }
            }
            .sheet(isPresented: $showingAddGoal) {
                AddGoalView(viewModel: viewModel)
            }
            .alert(viewModel.lastMilestoneMessage, isPresented: $viewModel.showingMilestoneReward) {
                Button("Awesome!", role: .cancel) {}
            }
        }
    }
}

struct GoalRowView: View {
    let goal: Goal

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: goal.category.icon)
                    .foregroundColor(goal.isCompleted ? .secondary : .blue)
                Text(goal.title)
                    .font(.headline)
                    .strikethrough(goal.isCompleted, color: .secondary)
                Spacer()
                Text("\(goal.progressPercent)%")
                    .font(.caption)
                    .foregroundColor(goal.isCompleted ? .green : .secondary)
                    .bold(goal.isCompleted)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(goal.isCompleted ? Color.green : Color.blue)
                        .frame(width: geo.size.width * goal.progressFraction, height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                Text(goal.category.displayName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                if goal.trackingType != .manual {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundColor(.pink)
                }
                Text(progressLabel)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var progressLabel: String {
        let unit = goal.trackingType.unit
        let current = formatValue(goal.currentProgress)
        let target = formatValue(goal.targetValue)
        if unit.isEmpty {
            return "\(current) / \(target)"
        }
        return "\(current) / \(target) \(unit)"
    }

    private func formatValue(_ val: Double) -> String {
        val >= 1000 ? String(format: "%.1fk", val / 1000) : String(format: "%.0f", val)
    }
}

struct GoalsEmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "flag.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Goals Yet")
                .font(.title2)
                .bold()
            Text("Set a long-term goal and earn rewards as you hit milestones.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

#Preview {
    GoalsView(viewModel: .preview)
}
