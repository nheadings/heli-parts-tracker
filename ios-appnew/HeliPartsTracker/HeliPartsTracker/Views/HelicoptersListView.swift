import SwiftUI

struct HelicoptersListView: View {
    @EnvironmentObject var viewModel: HelicoptersViewModel
    @EnvironmentObject var partsViewModel: PartsViewModel
    @State private var showingAddHelicopter = false

    var body: some View {
        NavigationView {
            List {
                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }

                ForEach(viewModel.helicopters) { helicopter in
                    NavigationLink(destination: HelicopterDetailView(helicopter: helicopter, viewModel: viewModel)
                        .environmentObject(partsViewModel)
                        .onAppear {
                            viewModel.selectedHelicopter = helicopter
                        }) {
                        HelicopterRowView(helicopter: helicopter, isSelected: viewModel.selectedHelicopter?.id == helicopter.id)
                    }
                }
                .onDelete(perform: deleteHelicopters)
            }
            .navigationTitle("Helicopters")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddHelicopter = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddHelicopter) {
                AddHelicopterView(viewModel: viewModel)
            }
            .task {
                await viewModel.loadHelicopters()
            }
            .refreshable {
                await viewModel.loadHelicopters()
            }
        }
    }

    private func deleteHelicopters(at offsets: IndexSet) {
        for index in offsets {
            let helicopter = viewModel.helicopters[index]
            Task {
                await viewModel.deleteHelicopter(helicopter)
            }
        }
    }
}

struct HelicopterRowView: View {
    let helicopter: Helicopter
    var isSelected: Bool = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(helicopter.tailNumber)
                    .font(.headline)

                HStack {
                    Text(helicopter.model)
                        .font(.subheadline)
                    if let manufacturer = helicopter.manufacturer {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(manufacturer)
                            .font(.subheadline)
                    }
                    if let year = helicopter.yearManufactured {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text("\(year)")
                            .font(.subheadline)
                    }
                }
                .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
            }
        }
    }
}
