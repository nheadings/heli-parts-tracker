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
