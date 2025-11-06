import SwiftUI

struct AddFluidLogView: View {
    let helicopterId: Int
    let existingLog: FluidLog?
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: LogbookViewModel

    @State private var fluidType = "engine_oil"
    @State private var quantity = ""
    @State private var unit = "quarts"
    @State private var hours = ""
    @State private var dateAdded = Date()
    @State private var notes = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showEditWarning = false
    @State private var showDeleteWarning = false
    @State private var isInitialized = false

    let fluidTypes = [
        ("engine_oil", "Engine Oil"),
        ("transmission_oil", "Transmission Oil"),
        ("hydraulic_fluid", "Hydraulic Fluid"),
        ("fuel", "Fuel")
    ]

    let units = ["quarts", "liters", "gallons"]

    init(helicopterId: Int, existingLog: FluidLog? = nil) {
        self.helicopterId = helicopterId
        self.existingLog = existingLog
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Fluid Type")) {
                    Picker("Type", selection: $fluidType) {
                        ForEach(fluidTypes, id: \.0) { type in
                            Text(type.1).tag(type.0)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section(header: Text("Quantity")) {
                    HStack {
                        TextField("Quantity", text: $quantity)
                            .keyboardType(.decimalPad)

                        Picker("Unit", selection: $unit) {
                            ForEach(units, id: \.self) { unit in
                                Text(unit.capitalized).tag(unit)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section(header: Text("Details")) {
                    DatePicker("Date Added", selection: $dateAdded, displayedComponents: .date)

                    HStack {
                        Text("Tach Hours")
                        Spacer()
                        TextField("Optional", text: $hours)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                        TextEditor(text: $notes)
                            .frame(height: 100)
                            .padding(4)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(existingLog == nil ? "Add Fluid" : "Edit Fluid")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if !isInitialized, let log = existingLog {
                    populateFields(from: log)
                    isInitialized = true
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if existingLog != nil {
                    ToolbarItem(placement: .bottomBar) {
                        Button(role: .destructive, action: {
                            showDeleteWarning = true
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                        .disabled(isSaving)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if existingLog != nil {
                            showEditWarning = true
                        } else {
                            save()
                        }
                    }) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(isSaving || quantity.isEmpty)
                }
            }
            .alert("Edit Logbook Entry?", isPresented: $showEditWarning) {
                Button("Cancel", role: .cancel) {}
                Button("Save Changes", role: .destructive) {
                    save()
                }
            } message: {
                Text("You are editing a historical logbook entry. This will modify permanent maintenance records. Are you sure you want to continue?")
            }
            .alert("Delete Logbook Entry?", isPresented: $showDeleteWarning) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteEntry()
                }
            } message: {
                Text("This will permanently delete this fluid log entry. This action cannot be undone.")
            }
        }
    }

    private func save() {
        guard let qty = Double(quantity), qty > 0 else {
            errorMessage = "Please enter a valid quantity"
            return
        }

        isSaving = true
        errorMessage = nil

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        let log = FluidLogCreate(
            fluidType: fluidType,
            quantity: qty,
            unit: unit,
            hours: hours.isEmpty ? nil : Double(hours),
            dateAdded: formatter.string(from: dateAdded),
            notes: notes.isEmpty ? nil : notes
        )

        Task {
            do {
                if let existing = existingLog {
                    // Update existing log
                    try await viewModel.updateFluidLog(id: existing.id, log: log)
                } else {
                    // Create new log
                    try await viewModel.createFluidLog(helicopterId: helicopterId, log: log)
                }

                await MainActor.run {
                    dismiss()
                }

                // Reload dashboard after dismiss animation
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                await viewModel.loadDashboard(helicopterId: helicopterId)
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                }
            }
        }
    }

    private func deleteEntry() {
        guard let existing = existingLog else { return }

        isSaving = true
        errorMessage = nil

        Task {
            do {
                try await viewModel.deleteFluidLog(id: existing.id, helicopterId: helicopterId)
                await MainActor.run {
                    dismiss()
                }

                // Reload dashboard after dismiss animation
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                await viewModel.loadDashboard(helicopterId: helicopterId)
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to delete: \(error.localizedDescription)"
                }
            }
        }
    }

    private func populateFields(from log: FluidLog) {
        fluidType = log.fluidType
        quantity = String(format: "%.1f", log.quantity)
        unit = log.unit
        if let logHours = log.hours {
            hours = String(format: "%.1f", logHours)
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        if let date = formatter.date(from: log.dateAdded) {
            dateAdded = date
        }

        if let logNotes = log.notes {
            notes = logNotes
        }
    }
}
