import SwiftUI
import PhotosUI

struct GoalDetailView: View {
    @ObservedObject var viewModel: UserViewModel
    let goal: Goal

    @State private var showingLogProgress = false
    @State private var logValue = ""
    @State private var selectedPhoto: PhotosPickerItem?

    private var liveGoal: Goal? {
        viewModel.goals.first(where: { $0.id == goal.id })
    }

    var body: some View {
        guard let current = liveGoal else {
            return AnyView(Text("Goal not found").foregroundColor(.secondary))
        }
        return AnyView(content(for: current))
    }

    @ViewBuilder
    private func content(for current: Goal) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                progressCard(for: current)
                milestoneCard(for: current)
                photoCard(for: current)
                if !current.isCompleted {
                    actionButtons(for: current)
                }
            }
            .padding()
        }
        .navigationTitle(current.title)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingLogProgress) {
            logProgressSheet(for: current)
        }
        .onChange(of: selectedPhoto) { item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) {
                    viewModel.updateGoalPhoto(goalId: current.id, photoData: data)
                }
            }
        }
    }

    @ViewBuilder
    private func progressCard(for current: Goal) -> some View {
        VStack(spacing: 12) {
            HStack {
                Label(current.category.displayName, systemImage: current.category.icon)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                if current.trackingType != .manual {
                    Label("HealthKit", systemImage: "heart.fill")
                        .font(.caption)
                        .foregroundColor(.pink)
                }
            }
            progressRing(for: current)
            progressStats(for: current)
            if let targetDate = current.targetDate {
                HStack {
                    Image(systemName: "calendar").foregroundColor(.secondary)
                    Text("Target: \(targetDate, style: .date)")
                        .font(.caption).foregroundColor(.secondary)
                    Spacer()
                }
            }
            if let notes = current.notes, !notes.isEmpty {
                HStack {
                    Text(notes).font(.caption).foregroundColor(.secondary).italic()
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func progressRing(for current: Goal) -> some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 12)
            Circle()
                .trim(from: 0, to: current.progressFraction)
                .stroke(current.isCompleted ? Color.green : Color.blue,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: current.progressFraction)
            VStack(spacing: 4) {
                Text("\(current.progressPercent)%")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text("complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 160, height: 160)
    }

    @ViewBuilder
    private func progressStats(for current: Goal) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Progress")
                    .font(.caption).foregroundColor(.secondary)
                Text(formatValue(current.currentProgress, unit: current.trackingType.unit))
                    .font(.headline)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("Target")
                    .font(.caption).foregroundColor(.secondary)
                Text(formatValue(current.targetValue, unit: current.trackingType.unit))
                    .font(.headline)
            }
        }
    }

    @ViewBuilder
    private func milestoneCard(for current: Goal) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Milestones")
                .font(.headline)

            ForEach([25, 50, 75, 100], id: \.self) { threshold in
                let earned = current.awardedMilestones.contains(threshold)
                HStack(spacing: 12) {
                    Image(systemName: earned ? "checkmark.seal.fill" : "seal")
                        .foregroundColor(earned ? milestoneColor(threshold) : .secondary)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(threshold)% Complete")
                            .font(.subheadline)
                            .bold(earned)
                        Text(milestoneRewardLabel(threshold))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if earned {
                        Text("Earned")
                            .font(.caption2)
                            .bold()
                            .foregroundColor(milestoneColor(threshold))
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func photoCard(for current: Goal) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress Photo")
                .font(.headline)

            if let data = current.photoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(8)
            }

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label(current.photoData == nil ? "Attach Photo" : "Change Photo", systemImage: "photo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func actionButtons(for current: Goal) -> some View {
        if current.trackingType == .manual {
            Button(action: { showingLogProgress = true }, label: {
                Label("Log Progress", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            })
            .buttonStyle(.borderedProminent)
        } else {
            Text("Progress tracked automatically via HealthKit")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func logProgressSheet(for current: Goal) -> some View {
        NavigationView {
            Form {
                Section(header: Text("New Total Progress")) {
                    HStack {
                        TextField("Value", text: $logValue)
                            .keyboardType(.decimalPad)
                        if !current.trackingType.unit.isEmpty {
                            Text(current.trackingType.unit)
                                .foregroundColor(.secondary)
                        }
                    }
                    Text("Current: \(formatValue(current.currentProgress, unit: current.trackingType.unit))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Target: \(formatValue(current.targetValue, unit: current.trackingType.unit))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Log Progress")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingLogProgress = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let value = Double(logValue) {
                            viewModel.updateManualProgress(goalId: current.id, newValue: value)
                        }
                        showingLogProgress = false
                    }
                    .disabled(Double(logValue) == nil)
                }
            }
        }
    }

    private func milestoneColor(_ threshold: Int) -> Color {
        switch threshold {
        case 25:  return .blue
        case 50:  return .orange
        case 75:  return .purple
        case 100: return .green
        default:  return .secondary
        }
    }

    private func milestoneRewardLabel(_ threshold: Int) -> String {
        switch threshold {
        case 25:  return "+25 XP, +10 Gold, +1 stat"
        case 50:  return "+50 XP, +25 Gold, +2 stats"
        case 75:  return "+100 XP, +50 Gold, +3 stats"
        case 100: return "+200 XP, +100 Gold, +5 stats, Trophy"
        default:  return ""
        }
    }

    private func formatValue(_ val: Double, unit: String) -> String {
        let numStr = val >= 1000 ? String(format: "%.1fk", val / 1000) : String(format: "%.0f", val)
        return unit.isEmpty ? numStr : "\(numStr) \(unit)"
    }
}

#Preview {
    NavigationView {
        GoalDetailView(viewModel: .preview, goal: Goal.previewGoals[0])
    }
}
