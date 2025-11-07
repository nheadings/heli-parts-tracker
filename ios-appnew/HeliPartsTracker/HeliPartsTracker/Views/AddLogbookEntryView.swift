import SwiftUI

struct AddLogbookEntryView: View {
    let existingEntry: LogbookEntryDetail?
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var helicoptersViewModel: HelicoptersViewModel
    @EnvironmentObject var viewModel: UnifiedLogbookViewModel

    @State private var selectedHelicopterId: Int = 0
    @State private var selectedCategoryId: Int = 0
    @State private var eventDate = Date()
    @State private var hoursAtEvent = ""
    @State private var description = ""
    @State private var notes = ""
    @State private var cost = ""
    @State private var nextDueHours = ""
    @State private var nextDueDate: Date? = nil
    @State private var includeNextDueDate = false

    @State private var isSaving = false
    @State private var errorMessage: String?

    init(existingEntry: LogbookEntryDetail? = nil, onSave: @escaping () -> Void) {
        self.existingEntry = existingEntry
        self.onSave = onSave
    }

    var body: some View {
        NavigationView {
            Form {
                // Basic Info Section
                Section("Event Information") {
                    Picker("Aircraft", selection: $selectedHelicopterId) {
                        ForEach(helicoptersViewModel.helicopters) { heli in
                            Text(heli.tailNumber).tag(heli.id)
                        }
                    }

                    Picker("Category", selection: $selectedCategoryId) {
                        ForEach(viewModel.categories) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.name)
                            }
                            .tag(category.id)
                        }
                    }

                    DatePicker("Date & Time", selection: $eventDate, displayedComponents: [.date, .hourAndMinute])

                    TextField("Hours at Event", text: $hoursAtEvent)
                        .keyboardType(.decimalPad)
                }

                // Description Section
                Section("Description") {
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)

                    TextField("Notes (Optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                // Financial Section
                Section("Financial") {
                    TextField("Cost (Optional)", text: $cost)
                        .keyboardType(.decimalPad)
                }

                // Next Due Section
                Section("Next Due (Optional)") {
                    TextField("Next Due Hours", text: $nextDueHours)
                        .keyboardType(.decimalPad)

                    Toggle("Set Next Due Date", isOn: $includeNextDueDate)

                    if includeNextDueDate {
                        DatePicker("Next Due Date", selection: Binding(
                            get: { nextDueDate ?? Date() },
                            set: { nextDueDate = $0 }
                        ), displayedComponents: .date)
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
            .navigationTitle(existingEntry == nil ? "Add Entry" : "Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveEntry()
                        }
                    }
                    .disabled(isSaving || !isValid)
                }
            }
        }
        .onAppear {
            loadExistingData()
        }
    }

    private var isValid: Bool {
        !description.isEmpty && selectedHelicopterId > 0 && selectedCategoryId > 0
    }

    private func loadExistingData() {
        if let existing = existingEntry {
            selectedHelicopterId = existing.helicopterId
            selectedCategoryId = existing.categoryId

            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: existing.eventDate) {
                eventDate = date
            }

            if let hours = existing.hoursAtEvent {
                hoursAtEvent = String(format: "%.1f", hours)
            }

            description = existing.description
            notes = existing.notes ?? ""

            if let existingCost = existing.cost {
                cost = String(format: "%.2f", existingCost)
            }

            if let nextHours = existing.nextDueHours {
                nextDueHours = String(format: "%.1f", nextHours)
            }

            if let nextDate = existing.nextDueDate {
                includeNextDueDate = true
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                if let date = dateFormatter.date(from: nextDate) {
                    self.nextDueDate = date
                }
            }
        } else {
            // New entry defaults
            if let firstHeli = helicoptersViewModel.helicopters.first {
                selectedHelicopterId = firstHeli.id
                if let currentHours = firstHeli.currentHours {
                    hoursAtEvent = String(format: "%.1f", currentHours)
                }
            }
            if let firstCategory = viewModel.categories.first {
                selectedCategoryId = firstCategory.id
            }
        }
    }

    private func saveEntry() async {
        errorMessage = nil
        isSaving = true

        let formatter = ISO8601DateFormatter()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let entryCreate = LogbookEntryCreate(
            helicopterId: selectedHelicopterId,
            categoryId: selectedCategoryId,
            eventDate: formatter.string(from: eventDate),
            hoursAtEvent: Double(hoursAtEvent),
            description: description,
            notes: notes.isEmpty ? nil : notes,
            cost: cost.isEmpty ? nil : Double(cost),
            nextDueHours: nextDueHours.isEmpty ? nil : Double(nextDueHours),
            nextDueDate: includeNextDueDate && nextDueDate != nil ? dateFormatter.string(from: nextDueDate!) : nil
        )

        do {
            if let existing = existingEntry {
                _ = try await APIService.shared.updateLogbookEntry(id: existing.id, entry: entryCreate)
            } else {
                _ = try await APIService.shared.createLogbookEntry(entry: entryCreate)
            }

            onSave()
            dismiss()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }

        isSaving = false
    }
}
