import SwiftUI

struct AddHelicopterView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: HelicoptersViewModel

    @State private var tailNumber = ""
    @State private var model = ""
    @State private var manufacturer = ""
    @State private var yearManufactured = ""
    @State private var serialNumber = ""
    @State private var status = ""
    @State private var showingError = false

    var body: some View {
        NavigationView {
            Form {
                Section("Required Information") {
                    TextField("Tail Number", text: $tailNumber)
                    TextField("Model", text: $model)
                }

                Section("Details") {
                    TextField("Manufacturer", text: $manufacturer)
                    TextField("Year Manufactured", text: $yearManufactured)
                        .keyboardType(.numberPad)
                    TextField("Serial Number", text: $serialNumber)
                }

                Section("Status") {
                    TextField("Status", text: $status)
                        .placeholder(when: status.isEmpty) {
                            Text("e.g., Active, Maintenance, Retired")
                                .foregroundColor(.gray)
                        }
                }
            }
            .navigationTitle("Add Helicopter")
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
        }
    }

    private var isFormValid: Bool {
        !tailNumber.isEmpty && !model.isEmpty
    }

    private func saveHelicopter() async {
        let helicopter = HelicopterCreate(
            tailNumber: tailNumber,
            model: model,
            manufacturer: manufacturer.isEmpty ? nil : manufacturer,
            yearManufactured: Int(yearManufactured),
            serialNumber: serialNumber.isEmpty ? nil : serialNumber,
            status: status.isEmpty ? nil : status
        )

        let success = await viewModel.createHelicopter(helicopter)
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
