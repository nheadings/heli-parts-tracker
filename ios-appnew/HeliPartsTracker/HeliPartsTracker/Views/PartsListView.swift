import SwiftUI

struct PartsListView: View {
    @EnvironmentObject var viewModel: PartsViewModel
    @State private var showingAddPart = false
    @State private var showingQRScanner = false

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                } else {
                    List {
                        ForEach(viewModel.filteredParts) { part in
                            NavigationLink(destination: PartDetailView(part: part)) {
                                PartRowView(part: part)
                            }
                        }
                        .onDelete(perform: deleteParts)
                    }
                    .searchable(text: $viewModel.searchQuery, prompt: "Search by part number or description")
                }
            }
            .navigationTitle("Parts Inventory")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(.blue)
                            .font(.system(size: 16))
                        Picker("Filter", selection: $viewModel.lifeLimitedFilter) {
                            ForEach(PartsViewModel.LifeLimitedFilter.allCases, id: \.self) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingQRScanner = true }) {
                        Image(systemName: "qrcode.viewfinder")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddPart = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddPart) {
                AddPartView()
                    .environmentObject(viewModel)
            }
            .sheet(isPresented: $showingQRScanner) {
                QRScannerView()
                    .environmentObject(viewModel)
            }
            .onAppear {
                Task {
                    await viewModel.loadParts()
                }
            }
        }
    }

    private func deleteParts(at offsets: IndexSet) {
        for index in offsets {
            let part = viewModel.filteredParts[index]
            Task {
                await viewModel.deletePart(part)
            }
        }
    }
}

struct PartRowView: View {
    let part: Part

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(part.partNumber)
                    .font(.headline)
                    .foregroundColor(part.isLifeLimited == true ? .orange : .primary)
                Spacer()
                if part.isLifeLimited == true {
                    Image(systemName: "clock.badge.exclamationmark.fill")
                        .foregroundColor(.orange)
                }
                if part.isLowStock {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                }
            }

            Text(part.description)
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack {
                Text("Stock: \(part.quantityInStock)")
                    .font(.caption)
                    .foregroundColor(part.isLowStock ? .red : .primary)

                if let price = part.unitPrice {
                    Spacer()
                    Text(String(format: "$%.2f", price))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(part.isLifeLimited == true ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 2)
        )
    }
}
