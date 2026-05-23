import SwiftUI

struct AddGoalView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: UserViewModel

    @State private var title = ""
    @State private var description = ""
    @State private var category: GoalCategory = .fitness
    @State private var trackingType: GoalTrackingType = .manual
    @State private var targetValue: Double = 100
    @State private var targetValueText = "100"
    @State private var hasTargetDate = false
    @State private var targetDate = Date().addingTimeInterval(30 * 24 * 3600)
    @State private var notes = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Goal Details")) {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description)
                }

                Section(header: Text("Category")) {
                    Picker("Category", selection: $category) {
                        ForEach(GoalCategory.allCases, id: \.self) { cat in
                            Label(cat.displayName, systemImage: cat.icon).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section(header: Text("Tracking")) {
                    Picker("Method", selection: $trackingType) {
                        ForEach(GoalTrackingType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text("Target")
                        Spacer()
                        TextField("Target", text: $targetValueText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .onChange(of: targetValueText) { newValue in
                                if let parsed = Double(newValue) {
                                    targetValue = parsed
                                }
                            }
                        if !trackingType.unit.isEmpty {
                            Text(trackingType.unit)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section(header: Text("Optional")) {
                    Toggle("Set Target Date", isOn: $hasTargetDate)
                    if hasTargetDate {
                        DatePicker("Target Date", selection: $targetDate, displayedComponents: .date)
                    }
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3)
                }
            }
            .navigationTitle("New Goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        var goal = Goal(
                            title: title,
                            description: description,
                            category: category,
                            trackingType: trackingType,
                            targetValue: targetValue
                        )
                        goal.targetDate = hasTargetDate ? targetDate : nil
                        goal.notes = notes.isEmpty ? nil : notes
                        viewModel.addGoal(goal)
                        dismiss()
                    }
                    .disabled(title.isEmpty || targetValue <= 0)
                }
            }
        }
    }
}

#Preview {
    AddGoalView(viewModel: .preview)
}
