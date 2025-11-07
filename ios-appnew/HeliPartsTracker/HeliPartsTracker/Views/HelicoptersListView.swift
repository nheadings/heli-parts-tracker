import SwiftUI

struct HelicoptersListView: View {
    @EnvironmentObject var viewModel: HelicoptersViewModel
    @EnvironmentObject var partsViewModel: PartsViewModel
    @State private var showingAddHelicopter = false
    @State private var helicopterToDelete: Helicopter?
    @State private var showingFirstDeleteWarning = false
    @State private var showingSecondDeleteWarning = false

    var body: some View {
        NavigationView {
            helicoptersList
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
        .alert("⚠️ DELETE AIRCRAFT?", isPresented: $showingFirstDeleteWarning, actions: {
            Button("Cancel", role: .cancel) {
                helicopterToDelete = nil
            }
            Button("Continue", role: .destructive) {
                showingSecondDeleteWarning = true
            }
        }, message: {
            Text(firstDeleteMessage)
        })
        .alert("⚠️⚠️ FINAL WARNING ⚠️⚠️", isPresented: $showingSecondDeleteWarning, actions: {
            Button("Cancel - Keep Aircraft", role: .cancel) {
                helicopterToDelete = nil
            }
            Button("YES - DELETE PERMANENTLY", role: .destructive) {
                performDelete()
            }
        }, message: {
            Text(secondDeleteMessage)
        })
    }

    private var helicoptersList: some View {
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
                helicopterRow(for: helicopter)
            }
        }
    }

    @ViewBuilder
    private func helicopterRow(for helicopter: Helicopter) -> some View {
        NavigationLink(destination: HelicopterDetailView(helicopter: helicopter, viewModel: viewModel)
            .environmentObject(partsViewModel)
            .onAppear {
                viewModel.selectedHelicopter = helicopter
            }) {
            HelicopterRowView(helicopter: helicopter, isSelected: viewModel.selectedHelicopter?.id == helicopter.id)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                helicopterToDelete = helicopter
                showingFirstDeleteWarning = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var firstDeleteMessage: String {
        guard let helicopter = helicopterToDelete else { return "" }
        return "Are you ABSOLUTELY SURE you want to delete \(helicopter.tailNumber)? This will permanently delete ALL flights, parts, and maintenance records for this aircraft."
    }

    private var secondDeleteMessage: String {
        guard let helicopter = helicopterToDelete else { return "" }
        return "LAST CHANCE! Deleting \(helicopter.tailNumber) is PERMANENT and CANNOT BE UNDONE. All associated data will be LOST FOREVER. Are you 100% certain?"
    }

    private func performDelete() {
        guard let helicopter = helicopterToDelete else { return }
        Task {
            await viewModel.deleteHelicopter(helicopter)
            helicopterToDelete = nil
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
        }
    }
}
