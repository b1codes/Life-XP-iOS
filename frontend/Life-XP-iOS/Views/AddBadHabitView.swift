import SwiftUI

struct AddBadHabitView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: UserViewModel

    @State private var title = ""
    @State private var category: BadHabitCategory = .smoking
    @State private var customCategoryName = ""
    @State private var whyNote = ""
    @State private var startDate = Date()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Vice Details")) {
                    TextField("Name (e.g., Vaping, Late Night Snacks)", text: $title)
                    TextField("Motivation / 'Why' (Optional)", text: $whyNote)
                }

                Section(header: Text("Category")) {
                    Picker("Category", selection: $category) {
                        ForEach(BadHabitCategory.allCases, id: \.self) { cat in
                            Label(cat.displayName, systemImage: cat.icon).tag(cat)
                        }
                    }
                    
                    if category == .custom {
                        TextField("Custom Category Name", text: $customCategoryName)
                    }
                }

                Section(header: Text("Start Date")) {
                    DatePicker(
                        "Tracking Started On",
                        selection: $startDate,
                        in: ...Date(),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    Text("Your streak begins from this date and time.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Track Vice to Break")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Track") {
                        viewModel.addBadHabit(
                            title: title,
                            category: category,
                            customCategoryName: category == .custom ? customCategoryName : nil,
                            whyNote: whyNote.isEmpty ? nil : whyNote,
                            startDate: startDate
                        )
                        dismiss()
                    }
                    .disabled(title.isEmpty || (category == .custom && customCategoryName.isEmpty))
                }
            }
        }
    }
}

#Preview {
    AddBadHabitView(viewModel: .preview)
}
