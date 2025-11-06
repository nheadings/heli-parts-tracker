import SwiftUI

struct AddPartView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: PartsViewModel
    @StateObject private var locationManager = LocationManager.shared

    var defaultPartNumber: String?
    var existingPart: Part?

    @State private var partNumber = ""
    @State private var alternatePartNumber = ""
    @State private var description = ""
    @State private var manufacturer = ""
    @State private var category = ""
    @State private var quantityInStock = ""
    @State private var minimumQuantity = ""
    @State private var unitPrice = ""
    @State private var reorderUrl = ""
    @State private var location = ""
    @State private var isLifeLimited = false
    @State private var showingError = false

    var body: some View {
        NavigationView {
            Form {
                Section("Required Information") {
                    TextField("Part Number", text: $partNumber)
                    TextField("Alternate Part Number", text: $alternatePartNumber)
                    TextField("Description", text: $description)
                }

                Section("Details") {
                    TextField("Manufacturer", text: $manufacturer)
                    TextField("Category", text: $category)

                    Picker("Location", selection: $location) {
                        Text("None").tag("")
                        ForEach(locationManager.locations, id: \.self) { loc in
                            Text(loc).tag(loc)
                        }
                    }

                    Picker("Life-Limited Part", selection: $isLifeLimited) {
                        Text("No").tag(false)
                        Text("Yes").tag(true)
                    }
                }

                Section("Inventory") {
                    TextField("Quantity in Stock", text: $quantityInStock)
                        .keyboardType(.numberPad)
                    TextField("Minimum Quantity", text: $minimumQuantity)
                        .keyboardType(.numberPad)
                }

                Section("Pricing") {
                    TextField("Unit Price", text: $unitPrice)
                        .keyboardType(.decimalPad)
                }

                Section("Reorder") {
                    TextField("Reorder URL", text: $reorderUrl)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle(existingPart == nil ? "Add Part" : "Edit Part")
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
                            await savePart()
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
                if let part = existingPart {
                    // Editing existing part
                    partNumber = part.partNumber
                    alternatePartNumber = part.alternatePartNumber ?? ""
                    description = part.description
                    manufacturer = part.manufacturer ?? ""
                    category = part.category ?? ""
                    quantityInStock = "\(part.quantityInStock)"
                    minimumQuantity = part.minimumQuantity.map { "\($0)" } ?? ""
                    unitPrice = part.unitPrice.map { String(format: "%.2f", $0) } ?? ""
                    reorderUrl = part.reorderUrl ?? ""
                    location = part.location ?? ""
                    isLifeLimited = part.isLifeLimited ?? false
                } else if let defaultPart = defaultPartNumber {
                    // New part with default part number
                    partNumber = defaultPart
                }
            }
        }
    }

    private var isFormValid: Bool {
        !partNumber.isEmpty && !description.isEmpty
    }

    private func savePart() async {
        let partData = PartCreate(
            partNumber: partNumber,
            alternatePartNumber: alternatePartNumber.isEmpty ? nil : alternatePartNumber,
            description: description,
            manufacturer: manufacturer.isEmpty ? nil : manufacturer,
            category: category.isEmpty ? nil : category,
            quantityInStock: Int(quantityInStock) ?? 0,
            minimumQuantity: Int(minimumQuantity),
            unitPrice: Double(unitPrice),
            reorderUrl: reorderUrl.isEmpty ? nil : reorderUrl,
            location: location.isEmpty ? nil : location,
            isLifeLimited: isLifeLimited
        )

        let success: Bool
        if let existingPart = existingPart {
            // Update existing part
            success = await viewModel.updatePart(id: existingPart.id, partData: partData)
        } else {
            // Create new part
            success = await viewModel.createPart(partData)
        }

        if success {
            dismiss()
        } else {
            showingError = true
        }
    }
}
