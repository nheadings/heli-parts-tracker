import SwiftUI

struct EditInstallationView: View {
    let installation: PartInstallation
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: LogbookViewModel

    @State private var serialNumber: String
    @State private var hoursAtInstallation: String
    @State private var notes: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showEditWarning = false
    @State private var showDeleteWarning = false

    init(installation: PartInstallation) {
        self.installation = installation

        // Initialize state properties from existing installation
        _serialNumber = State(initialValue: installation.serialNumber ?? "")
        _hoursAtInstallation = State(initialValue: installation.hoursAtInstallation ?? "")
        _notes = State(initialValue: installation.notes ?? "")
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Part Information")) {
                    HStack {
                        Text("Part Number")
                        Spacer()
                        Text(installation.partNumber ?? "N/A")
                            .foregroundColor(.secondary)
                    }

                    if let description = installation.partDescription {
                        HStack {
                            Text("Description")
                            Spacer()
                            Text(description)
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Text("Quantity")
                        Spacer()
                        Text("\(installation.quantityInstalled)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Installation Date")
                        Spacer()
                        Text(formatDate(installation.installationDate))
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Editable Details")) {
                    TextField("Serial Number", text: $serialNumber)

                    HStack {
                        Text("Hours at Installation")
                        Spacer()
                        TextField("Hours", text: $hoursAtInstallation)
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
            .navigationTitle("Edit Installation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .bottomBar) {
                    Button(role: .destructive, action: {
                        showDeleteWarning = true
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showEditWarning = true
                    }) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .alert("Edit Installation Record?", isPresented: $showEditWarning) {
                Button("Cancel", role: .cancel) {}
                Button("Save Changes", role: .destructive) {
                    save()
                }
            } message: {
                Text("You are editing a historical installation record. This will modify permanent maintenance records. Are you sure you want to continue?")
            }
            .alert("Delete Installation Record?", isPresented: $showDeleteWarning) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteEntry()
                }
            } message: {
                Text("This will permanently delete this installation record. This action cannot be undone.")
            }
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil

        let hours = hoursAtInstallation.isEmpty ? nil : Double(hoursAtInstallation)
        let serial = serialNumber.isEmpty ? nil : serialNumber
        let installationNotes = notes.isEmpty ? nil : notes

        Task {
            do {
                _ = try await APIService.shared.updateInstallation(
                    id: installation.id,
                    serialNumber: serial,
                    hoursAtInstallation: hours,
                    notes: installationNotes
                )

                await MainActor.run {
                    dismiss()
                }

                // Reload dashboard after dismiss animation
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                if let helicopterId = installation.helicopterId {
                    await viewModel.loadDashboard(helicopterId: helicopterId)
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                }
            }
        }
    }

    private func deleteEntry() {
        guard let helicopterId = installation.helicopterId else { return }

        isSaving = true
        errorMessage = nil

        Task {
            do {
                try await viewModel.deleteInstallation(id: installation.id, helicopterId: helicopterId)
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

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}
