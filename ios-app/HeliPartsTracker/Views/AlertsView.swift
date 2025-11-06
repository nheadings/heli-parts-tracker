import SwiftUI

struct AlertsView: View {
    @EnvironmentObject var partsViewModel: PartsViewModel

    var body: some View {
        NavigationView {
            VStack {
                if partsViewModel.isLoading {
                    ProgressView()
                } else {
                    List {
                        if partsViewModel.lowStockParts.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 60))
                                    .foregroundColor(.green)
                                Text("No Low Stock Alerts")
                                    .font(.headline)
                                Text("All parts are adequately stocked")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .listRowBackground(Color.clear)
                        } else {
                            ForEach(partsViewModel.lowStockParts) { part in
                                NavigationLink(destination: PartDetailView(part: part)) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(.red)
                                            Text(part.partNumber)
                                                .font(.headline)
                                        }

                                        Text(part.description)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)

                                        HStack {
                                            Text("In Stock:")
                                            Text("\(part.quantityInStock)")
                                                .fontWeight(.bold)
                                                .foregroundColor(.red)

                                            Spacer()

                                            if let minQty = part.minimumQuantity {
                                                Text("Min: \(minQty)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Low Stock Alerts")
            .task {
                await partsViewModel.loadLowStockParts()
            }
            .refreshable {
                await partsViewModel.loadLowStockParts()
            }
        }
    }
}
