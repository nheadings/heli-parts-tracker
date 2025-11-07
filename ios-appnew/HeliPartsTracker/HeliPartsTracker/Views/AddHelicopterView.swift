import SwiftUI

struct AddHelicopterView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: HelicoptersViewModel
    var helicopter: Helicopter? = nil  // If not nil, we're editing

    @State private var tailNumber = ""
    @State private var model = ""
    @State private var manufacturer = ""
    @State private var yearManufactured = ""
    @State private var serialNumber = ""
    @State private var status = ""
    @State private var showingError = false
    @State private var hasLoadedData = false

    var body: some View {
        NavigationView {
            Form {
                Section("Required Information") {
                    TextField("Tail Number", text: $tailNumber)
                    TextField("Model", text: $model)
                }

                Section("Details") {
                    HStack {
                        TextField("Manufacturer", text: $manufacturer)
                        if !manufacturer.isEmpty {
                            Button(action: {
                                manufacturer = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }

                    HStack {
                        TextField("Year Manufactured", text: $yearManufactured)
                            .keyboardType(.numberPad)
                        if !yearManufactured.isEmpty {
                            Button(action: {
                                yearManufactured = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }

                    HStack {
                        TextField("Serial Number", text: $serialNumber)
                        if !serialNumber.isEmpty {
                            Button(action: {
                                serialNumber = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }

                Section("Status") {
                    HStack {
                        TextField("Status", text: $status)
                            .placeholder(when: status.isEmpty) {
                                Text("e.g., Active, Maintenance, Retired")
                                    .foregroundColor(.gray)
                            }
                        if !status.isEmpty {
                            Button(action: {
                                status = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            .navigationTitle(helicopter == nil ? "Add Helicopter" : "Edit Helicopter")
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
                            await saveHelicopter()
                        }
                    }
                    .disabled(!isFormValid)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
            .onAppear {
                if !hasLoadedData, let helicopter = helicopter {
                    // Pre-populate fields when editing
                    tailNumber = helicopter.tailNumber
                    model = helicopter.model
                    manufacturer = helicopter.manufacturer ?? ""
                    yearManufactured = helicopter.yearManufactured.map { String($0) } ?? ""
                    serialNumber = helicopter.serialNumber ?? ""
                    status = helicopter.status ?? ""
                    hasLoadedData = true
                }
            }
        }
    }

    private var isFormValid: Bool {
        !tailNumber.isEmpty && !model.isEmpty
    }

    private func saveHelicopter() async {
        let trimmedManufacturer = manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSerial = serialNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedStatus = status.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedYear = yearManufactured.trimmingCharacters(in: .whitespacesAndNewlines)

        let helicopterData = HelicopterCreate(
            tailNumber: tailNumber,
            model: model,
            manufacturer: trimmedManufacturer.isEmpty ? nil : trimmedManufacturer,
            yearManufactured: trimmedYear.isEmpty ? nil : Int(trimmedYear),
            serialNumber: trimmedSerial.isEmpty ? nil : trimmedSerial,
            status: trimmedStatus.isEmpty ? nil : trimmedStatus
        )

        // Debug logging
        print("DEBUG - Saving helicopter:")
        print("  Tail Number: \(tailNumber)")
        print("  Model: \(model)")
        print("  Manufacturer: \(trimmedManufacturer.isEmpty ? "nil" : trimmedManufacturer)")
        print("  Year: \(trimmedYear.isEmpty ? "nil" : trimmedYear)")
        print("  Serial: \(trimmedSerial.isEmpty ? "nil" : trimmedSerial)")
        print("  Status: \(trimmedStatus.isEmpty ? "nil" : trimmedStatus)")

        let success: Bool
        if let existingHelicopter = helicopter {
            // Update existing helicopter
            print("DEBUG - Updating helicopter ID: \(existingHelicopter.id)")
            success = await viewModel.updateHelicopter(id: existingHelicopter.id, helicopterData)
        } else {
            // Create new helicopter
            success = await viewModel.createHelicopter(helicopterData)
        }

        if success {
            dismiss()
        } else {
            showingError = true
        }
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
