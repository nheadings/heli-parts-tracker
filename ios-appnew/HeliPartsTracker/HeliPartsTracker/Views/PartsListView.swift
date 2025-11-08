import SwiftUI

struct PartsListView: View {
    @EnvironmentObject var viewModel: PartsViewModel
    @State private var showingAddPart = false
    @State private var showingQRScanner = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search hint banner
                if !viewModel.searchHint.isEmpty {
                    Text(viewModel.searchHint)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGroupedBackground))
                }

                // Content
                Group {
                    if viewModel.isLoading {
                        ProgressView("Searching...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = viewModel.errorMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 50))
                                .foregroundColor(.red)
                            Text(error)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.filteredParts.isEmpty && viewModel.searchQuery.isEmpty {
                        // Empty state - no search yet
                        VStack(spacing: 16) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("Search Parts Inventory")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Type a part number or description to search")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Text("200,000+ parts available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.filteredParts.isEmpty && !viewModel.searchQuery.isEmpty {
                        // No results for search
                        VStack(spacing: 16) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("No Results")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("No parts found for '\(viewModel.searchQuery)'")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(viewModel.filteredParts) { part in
                                NavigationLink(destination: PartDetailView(part: part)) {
                                    PartRowView(part: part)
                                }
                            }
                            .onDelete(perform: deleteParts)
                        }
                        .refreshable {
                            await viewModel.refreshParts()
                        }
                    }
                }
            }
            .searchable(text: $viewModel.searchQuery, prompt: "Search part number or description")
            .navigationTitle("Parts Inventory")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Picker("Type", selection: $viewModel.lifeLimitedFilter) {
                            ForEach(PartsViewModel.LifeLimitedFilter.allCases, id: \.self) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }

                        Toggle("In Stock Only", isOn: $viewModel.inStockOnly)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            if viewModel.lifeLimitedFilter != .all || viewModel.inStockOnly {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundColor(.blue)
                            }
                        }
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
