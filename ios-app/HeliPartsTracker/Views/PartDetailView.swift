import SwiftUI

struct PartDetailView: View {
    let part: Part
    @Environment(\.openURL) var openURL
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: PartsViewModel
    @State private var showingAddQuantity = false
    @State private var quantityToAdd = ""
    @State private var showingDeleteConfirmation = false
    @State private var showingEditPart = false
    @State private var transactions: [InventoryTransaction] = []
    @State private var isLoadingTransactions = false

    var body: some View {
        List {
            Section("Information") {
                DetailRow(label: "Part Number", value: part.partNumber)
                if let altPartNumber = part.alternatePartNumber {
                    DetailRow(label: "Alternate Part #", value: altPartNumber)
                }
                DetailRow(label: "Description", value: part.description)
                if let manufacturer = part.manufacturer {
                    DetailRow(label: "Manufacturer", value: manufacturer)
                }
                if let category = part.category {
                    DetailRow(label: "Category", value: category)
                }
                if let location = part.location {
                    DetailRow(label: "Location", value: location)
                }
            }

            Section("Inventory") {
                DetailRow(label: "In Stock", value: "\(part.quantityInStock)")
                if let minQty = part.minimumQuantity {
                    DetailRow(label: "Minimum Quantity", value: "\(minQty)")
                }
                if part.isLowStock {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("Low Stock Alert")
                            .foregroundColor(.red)
                    }
                }
            }

            if let price = part.unitPrice {
                Section("Pricing") {
                    DetailRow(label: "Unit Price", value: String(format: "$%.2f", price))
                }
            }

            if let reorderUrl = part.reorderUrl, let url = URL(string: reorderUrl) {
                Section("Reorder") {
                    Button(action: {
                        openURL(url)
                    }) {
                        HStack {
                            Text("Open Vendor Website")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                    }
                }
            }

            if let qrCode = part.qrCode {
                Section("QR Code") {
                    if let image = generateQRCode(from: qrCode) {
                        Image(uiImage: image)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            Section("Transaction History") {
                if isLoadingTransactions {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if transactions.isEmpty {
                    Text("No transactions")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(transactions) { transaction in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(transaction.transactionType.capitalized)
                                    .font(.headline)
                                Spacer()
                                Text(formatQuantityChange(transaction.quantityChange))
                                    .font(.headline)
                                    .foregroundColor(transaction.quantityChange > 0 ? .green : .red)
                            }
                            if let username = transaction.performedByUsername {
                                HStack {
                                    Image(systemName: "person.circle")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    Text(username)
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                            HStack {
                                Text("Qty After: \(transaction.quantityAfter)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(formatTransactionDate(transaction.transactionDate))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if let notes = transaction.notes {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Actions") {
                Button(action: {
                    showingEditPart = true
                }) {
                    HStack {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundColor(.blue)
                        Text("Edit Part")
                        Spacer()
                    }
                }

                Button(action: {
                    showingAddQuantity = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                        Text("Add Quantity")
                        Spacer()
                    }
                }

                Button(role: .destructive, action: {
                    showingDeleteConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("Remove Part")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Part Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadTransactions()
        }
        .sheet(isPresented: $showingAddQuantity) {
            NavigationView {
                Form {
                    Section("Add Quantity") {
                        TextField("Quantity to add", text: $quantityToAdd)
                            .keyboardType(.numberPad)
                    }
                }
                .navigationTitle("Add Quantity")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            showingAddQuantity = false
                            quantityToAdd = ""
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Add") {
                            if let qty = Int(quantityToAdd), qty > 0 {
                                Task {
                                    await addQuantity(qty)
                                    showingAddQuantity = false
                                    quantityToAdd = ""
                                }
                            }
                        }
                        .disabled(quantityToAdd.isEmpty || Int(quantityToAdd) == nil)
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditPart) {
            AddPartView(existingPart: part)
                .environmentObject(viewModel)
        }
        .alert("Delete Part", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await deletePart()
                }
            }
        } message: {
            Text("Are you sure you want to delete this part? This action cannot be undone.")
        }
    }

    private func addQuantity(_ quantity: Int) async {
        let updatedPart = PartCreate(
            partNumber: part.partNumber,
            alternatePartNumber: part.alternatePartNumber,
            description: part.description,
            manufacturer: part.manufacturer,
            category: part.category,
            quantityInStock: part.quantityInStock + quantity,
            minimumQuantity: part.minimumQuantity,
            unitPrice: part.unitPrice,
            reorderUrl: part.reorderUrl,
            location: part.location
        )
        _ = await viewModel.updatePart(id: part.id, partData: updatedPart)
    }

    private func deletePart() async {
        await viewModel.deletePart(part)
        dismiss()
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let data = Data(string.utf8)
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            if let output = filter.outputImage {
                let transform = CGAffineTransform(scaleX: 10, y: 10)
                let scaledImage = output.transformed(by: transform)
                let context = CIContext()
                if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                    return UIImage(cgImage: cgImage)
                }
            }
        }
        return nil
    }

    private func loadTransactions() async {
        isLoadingTransactions = true
        do {
            transactions = try await APIService.shared.getPartTransactions(partId: part.id)
        } catch {
            print("Failed to load transactions: \(error)")
        }
        isLoadingTransactions = false
    }

    private func formatQuantityChange(_ change: Int) -> String {
        if change > 0 {
            return "+\(change)"
        } else {
            return "\(change)"
        }
    }

    private func formatTransactionDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
    }
}
