import SwiftUI

struct AddMaintenanceLogView: View {
    let helicopterId: Int
    let existingLog: MaintenanceLog?
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: LogbookViewModel

    @State private var logType = "oil_change"
    @State private var description = ""
    @State private var hoursAtService = ""
    @State private var datePerformed = Date()
    @State private var cost = ""
    @State private var nextDueHours = ""
    @State private var nextDueDate = Date()
    @State private var hasNextDueDate = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showEditWarning = false
    @State private var showDeleteWarning = false
    @State private var isInitialized = false

    let logTypes = [
        ("oil_change", "Oil Change"),
        ("inspection", "Inspection"),
        ("repair", "Repair"),
        ("ad_compliance", "AD Compliance"),
        ("service", "Service")
    ]

    init(helicopterId: Int, existingLog: MaintenanceLog? = nil) {
        self.helicopterId = helicopterId
        self.existingLog = existingLog
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Maintenance Type")) {
                    Picker("Type", selection: $logType) {
                        ForEach(logTypes, id: \.0) { type in
                            Text(type.1).tag(type.0)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section(header: Text("Details")) {
                    TextField("Description", text: $description)

                    HStack {
                        Text("Hours at Service")
                        Spacer()
                        TextField("Hours", text: $hoursAtService)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    DatePicker("Date Performed", selection: $datePerformed, displayedComponents: .date)

                    HStack {
                        Text("Cost")
                        Spacer()
                        TextField("Optional", text: $cost)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section(header: Text("Next Due")) {
                    HStack {
                        Text("Hours Until Next")
                        Spacer()
                        TextField("Optional", text: $nextDueHours)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    Toggle("Set Next Due Date", isOn: $hasNextDueDate)

                    if hasNextDueDate {
                        DatePicker("Next Due Date", selection: $nextDueDate, displayedComponents: .date)
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
            .navigationTitle(existingLog == nil ? "Add Maintenance" : "Edit Maintenance")
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
                    .disabled(isSaving || description.isEmpty)
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
                Text("This will permanently delete this maintenance log entry. This action cannot be undone.")
            }
        }
    }

    private func save() {
        guard !description.isEmpty else {
            errorMessage = "Description is required"
            return
        }

        isSaving = true
        errorMessage = nil

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        let log = MaintenanceLogCreate(
            logType: logType,
            hoursAtService: Double(hoursAtService),
            datePerformed: formatter.string(from: datePerformed),
            description: description,
            cost: cost.isEmpty ? nil : Double(cost),
            nextDueHours: nextDueHours.isEmpty ? nil : Double(nextDueHours),
            nextDueDate: hasNextDueDate ? formatter.string(from: nextDueDate) : nil,
            status: "completed"
        )

        Task {
            do {
                if let existing = existingLog {
                    // Update existing log
                    try await viewModel.updateMaintenanceLog(helicopterId: existing.helicopterId, id: existing.id, log: log)
                } else {
                    // Create new log
                    try await viewModel.createMaintenanceLog(helicopterId: helicopterId, log: log)
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
                try await viewModel.deleteMaintenanceLog(id: existing.id, helicopterId: helicopterId)
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

    private func populateFields(from log: MaintenanceLog) {
        logType = log.logType
        description = log.description
        if let hours = log.hoursAtService {
            hoursAtService = String(format: "%.1f", hours)
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        if let date = formatter.date(from: log.datePerformed) {
            datePerformed = date
        }

        if let logCost = log.cost {
            cost = String(format: "%.2f", logCost)
        }

        if let nextHours = log.nextDueHours {
            nextDueHours = String(format: "%.1f", nextHours)
        }

        if let nextDateString = log.nextDueDate, let nextDate = formatter.date(from: nextDateString) {
            hasNextDueDate = true
            nextDueDate = nextDate
        }
    }
}
