import SwiftUI

struct RelapseLogView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: UserViewModel
    let habit: BadHabit

    @State private var triggerNote = ""
    @State private var date = Date()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Reflection & Trigger")) {
                    Text("Be honest with yourself. Understanding triggers is the first step to overcoming them. There is no shame in a relapse — it's just a data point on your path to recovery.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)

                    ZStack(alignment: .topLeading) {
                        if triggerNote.isEmpty {
                            Text("What triggered this relapse? (e.g. stress, social setting, fatigue, boredom...)")
                                .font(.body)
                                .foregroundColor(.gray.opacity(0.6))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                        }
                        TextEditor(text: $triggerNote)
                            .frame(height: 120)
                            .padding(.horizontal, 0)
                    }
                }
                
                Section(header: Text("Relapse Time")) {
                    DatePicker("When did this happen?", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                }
                
                Section {
                    Button(action: logRelapseAndDismiss) {
                        Text("Log & Reset Streak")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                }
                .listRowInsets(EdgeInsets())
                .background(Color.clear)
            }
            .navigationTitle("Log Relapse")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func logRelapseAndDismiss() {
        let noteText = triggerNote.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.logRelapse(for: habit, note: noteText.isEmpty ? nil : noteText)
        dismiss()
    }
}

#Preview {
    RelapseLogView(viewModel: .preview, habit: BadHabit(title: "Smoking", category: .smoking, startDate: Date()))
}
