import SwiftUI

struct InstallPartView: View {
    let helicopter: Helicopter
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var helicoptersViewModel: HelicoptersViewModel
    @EnvironmentObject var partsViewModel: PartsViewModel

    @State private var selectedPart: Part?
    @State private var quantity = ""
    @State private var notes = ""
    @State private var showingError = false

    var body: some View {
        NavigationView {
            Form {
                Section("Part") {
                    Picker("Select Part", selection: $selectedPart) {
                        Text("Select a part").tag(nil as Part?)
                        ForEach(partsViewModel.parts) { part in
                            Text("\(part.partNumber) - \(part.description)")
                                .tag(part as Part?)
                        }
                    }

                    if let part = selectedPart {
                        HStack {
                            Text("Available")
                            Spacer()
                            Text("\(part.quantityInStock)")
                                .foregroundColor(part.quantityInStock > 0 ? .primary : .red)
                        }
                    }
                }

                Section("Installation Details") {
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.numberPad)

                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Install Part")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Install") {
                        Task {
                            await installPart()
                        }
                    }
                    .disabled(!isFormValid)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(helicoptersViewModel.errorMessage ?? "Unknown error")
            }
            .task {
                await partsViewModel.loadParts()
            }
        }
    }

    private var isFormValid: Bool {
        selectedPart != nil && !quantity.isEmpty && (Int(quantity) ?? 0) > 0
    }

    private func installPart() async {
        guard let part = selectedPart,
              let qty = Int(quantity),
              qty > 0 else { return }

        let success = await helicoptersViewModel.installPart(
            partId: part.id,
            helicopterId: helicopter.id,
            quantity: qty,
            notes: notes.isEmpty ? nil : notes
        )

        if success {
            dismiss()
        } else {
            showingError = true
        }
    }
}

// New view for installing parts from the Parts tab
struct InstallPartOnHelicopterView: View {
    let part: Part
    @Environment(\.dismiss) var dismiss
    @StateObject private var helicoptersViewModel = HelicoptersViewModel()
    @StateObject private var logbookViewModel = LogbookViewModel()

    @State private var selectedHelicopter: Helicopter?
    @State private var currentHours: String = ""
    @State private var isLoadingHours = false
    @State private var quantity = ""
    @State private var notes = ""
    @State private var showingError = false
    @State private var showingHoursConfirmation = false

    var body: some View {
        NavigationView {
            Form {
                Section("Part") {
                    HStack {
                        Text("Part Number")
                        Spacer()
                        Text(part.partNumber)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Description")
                        Spacer()
                        Text(part.description)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Available")
                        Spacer()
                        Text("\(part.quantityInStock)")
                            .foregroundColor(part.quantityInStock > 0 ? .primary : .red)
                    }
                }

                Section("Helicopter") {
                    Picker("Select Helicopter", selection: $selectedHelicopter) {
                        Text("Select a helicopter").tag(nil as Helicopter?)
                        ForEach(helicoptersViewModel.helicopters) { helicopter in
                            Text("\(helicopter.tailNumber) - \(helicopter.model)")
                                .tag(helicopter as Helicopter?)
                        }
                    }
                    .onChange(of: selectedHelicopter) { _, newValue in
                        if let helicopter = newValue {
                            loadCurrentHours(helicopterId: helicopter.id)
                        } else {
                            currentHours = ""
                        }
                    }

                    if isLoadingHours {
                        HStack {
                            Text("Loading hours...")
                            Spacer()
                            ProgressView()
                        }
                    } else if selectedHelicopter != nil {
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Current Hours", text: $currentHours)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.headline)

                            if !currentHours.isEmpty {
                                Text("Auto-populated from last tach entry")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section("Installation Details") {
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.numberPad)

                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Install Part")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Install") {
                        showingHoursConfirmation = true
                    }
                    .disabled(!isFormValid)
                }
            }
            .alert("Confirm Hours", isPresented: $showingHoursConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Confirm") {
                    Task {
                        await installPart()
                    }
                }
            } message: {
                Text("Current tach hours are \(currentHours). Is this correct?")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(helicoptersViewModel.errorMessage ?? "Unknown error")
            }
            .task {
                await helicoptersViewModel.loadHelicopters()
            }
        }
    }

    private var isFormValid: Bool {
        selectedHelicopter != nil &&
        !quantity.isEmpty &&
        (Int(quantity) ?? 0) > 0 &&
        !currentHours.isEmpty
    }

    private func loadCurrentHours(helicopterId: Int) {
        isLoadingHours = true
        Task {
            await logbookViewModel.loadDashboard(helicopterId: helicopterId)

            await MainActor.run {
                if let dashboard = logbookViewModel.dashboard {
                    currentHours = String(format: "%.1f", dashboard.helicopter.currentHours)
                } else {
                    currentHours = ""
                }
                isLoadingHours = false
            }
        }
    }

    private func installPart() async {
        guard let helicopter = selectedHelicopter,
              let qty = Int(quantity),
              qty > 0 else { return }

        let success = await helicoptersViewModel.installPart(
            partId: part.id,
            helicopterId: helicopter.id,
            quantity: qty,
            notes: notes.isEmpty ? nil : notes
        )

        if success {
            dismiss()
        } else {
            showingError = true
        }
    }
}
