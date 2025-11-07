import SwiftUI

struct AddMaintenanceCompletionView: View {
    @Environment(\.dismiss) var dismiss
    let helicopter: Helicopter
    let maintenanceItem: FlightViewMaintenance
    let onComplete: () -> Void

    @State private var notes: String = ""
    @State private var hoursAtCompletion: String
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(helicopter: Helicopter, maintenanceItem: FlightViewMaintenance, onComplete: @escaping () -> Void) {
        self.helicopter = helicopter
        self.maintenanceItem = maintenanceItem
        self.onComplete = onComplete
        _hoursAtCompletion = State(initialValue: String(format: "%.1f", helicopter.currentHours ?? 0))
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Maintenance Item")) {
                    HStack {
                        Circle()
                            .fill(Color(hex: maintenanceItem.color))
                            .frame(width: 20, height: 20)
                        Text(maintenanceItem.title)
                            .font(.headline)
                    }

                    HStack {
                        Text("Interval:")
                        Spacer()
                        Text("\(Int(maintenanceItem.intervalHours)) hours")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Aircraft")) {
                    Text(helicopter.tailNumber)
                        .font(.headline)

                    HStack {
                        Text("Hours at Completion:")
                        Spacer()
                        TextField("Hours", text: $hoursAtCompletion)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.headline)
                    }
                }

                Section(header: Text("Notes (Optional)")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Record Maintenance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveCompletion()
                        }
                    }
                    .disabled(isLoading)
                }
            }
        }
    }

    private func saveCompletion() async {
        isLoading = true
        errorMessage = nil

        // Validate hours input
        guard let hours = Double(hoursAtCompletion), hours > 0 else {
            errorMessage = "Please enter valid hours"
            isLoading = false
            return
        }

        // Get current user ID from UserDefaults
        let userId = UserDefaults.standard.integer(forKey: "userId")

        let completion = MaintenanceCompletionCreate(
            helicopterId: helicopter.id,
            templateId: maintenanceItem.id,
            hoursAtCompletion: hours,
            notes: notes.isEmpty ? nil : notes,
            completedBy: userId > 0 ? userId : nil
        )

        do {
            _ = try await APIService.shared.createMaintenanceCompletion(completion: completion)
            onComplete()
            dismiss()
        } catch let error as DecodingError {
            print("Decoding error: \(error)")
            errorMessage = "Server response format error. Check logs."
            isLoading = false
        } catch {
            print("Save error: \(error)")
            errorMessage = "Failed to save: \(error.localizedDescription)"
            isLoading = false
        }
    }
}
