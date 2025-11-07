import SwiftUI

struct HelicopterDetailView: View {
    let helicopterId: Int
    @ObservedObject var viewModel: HelicoptersViewModel
    @EnvironmentObject var partsViewModel: PartsViewModel
    @State private var showingInstallPart = false
    @State private var showingEdit = false
    @State private var showingDeleteConfirmation = false
    @State private var installationToDelete: PartInstallation?
    @State private var showingDeletionError = false
    @State private var deletionErrorMessage = ""

    // Computed property to get the current helicopter from the view model
    private var helicopter: Helicopter? {
        viewModel.helicopters.first { $0.id == helicopterId }
    }

    init(helicopter: Helicopter, viewModel: HelicoptersViewModel) {
        self.helicopterId = helicopter.id
        self.viewModel = viewModel
    }

    var body: some View {
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
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Error")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text(error)
                            .foregroundColor(.red)
                    }
                    .padding(.vertical, 4)
                }
            }

            if !viewModel.isLoading, let helicopter = helicopter {
                    Section("Helicopter Information") {
                        DetailRow(label: "Tail Number", value: helicopter.tailNumber)
                        DetailRow(label: "Model", value: helicopter.model)
                        if let manufacturer = helicopter.manufacturer {
                            DetailRow(label: "Manufacturer", value: manufacturer)
                        }
                        if let year = helicopter.yearManufactured {
                            DetailRow(label: "Year", value: "\(year)")
                        }
                        if let serial = helicopter.serialNumber {
                            DetailRow(label: "Serial Number", value: serial)
                        }
                    }

                    Section("Installed Parts") {
                        if viewModel.installedParts.isEmpty {
                            Text("No parts installed")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(viewModel.installedParts) { installation in
                                VStack(alignment: .leading, spacing: 4) {
                                    if let partNumber = installation.partNumber {
                                        Text(partNumber)
                                            .font(.headline)
                                    }
                                    if let description = installation.partDescription {
                                        Text(description)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    HStack {
                                        Text("Qty: \(installation.quantityInstalled)")
                                            .font(.caption)
                                        Spacer()
                                        Text(formatDate(installation.installationDate))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    if let installedBy = installation.installedByUsername {
                                        HStack {
                                            Image(systemName: "person.circle")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                            Text("Installed by \(installedBy)")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        installationToDelete = installation
                                        showingDeleteConfirmation = true
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
            }
        }
        .navigationTitle(helicopter?.tailNumber ?? "Helicopter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button(action: { showingEdit = true }) {
                        Image(systemName: "pencil")
                    }
                    Button(action: { showingInstallPart = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingInstallPart, onDismiss: {
            Task {
                await viewModel.loadHelicopterParts(helicopterId: helicopterId)
            }
        }) {
            if let helicopter = helicopter {
                InstallPartView(helicopter: helicopter)
                    .environmentObject(viewModel)
                    .environmentObject(partsViewModel)
            }
        }
        .sheet(isPresented: $showingEdit, onDismiss: {
            Task {
                await viewModel.loadHelicopters()
            }
        }) {
            if let helicopter = helicopter {
                AddHelicopterView(viewModel: viewModel, helicopter: helicopter)
            }
        }
        .task {
            await viewModel.loadHelicopterParts(helicopterId: helicopterId)
        }
        .refreshable {
            await viewModel.loadHelicopterParts(helicopterId: helicopterId)
        }
        .alert("Remove Part", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                installationToDelete = nil
                viewModel.errorMessage = nil
            }
            Button("Remove", role: .destructive) {
                if let installation = installationToDelete {
                    Task {
                        let success = await removeInstallation(installation)
                        if success {
                            installationToDelete = nil
                        }
                        // Don't dismiss on error - keep the alert context
                    }
                }
            }
        } message: {
            if let installation = installationToDelete {
                Text("Are you sure you want to remove \(installation.partNumber ?? "this part") from \(helicopter?.tailNumber ?? "this helicopter")?")
            } else {
                Text("Are you sure you want to remove this part from the helicopter?")
            }
        }
        .alert("Deletion Failed", isPresented: $showingDeletionError) {
            Button("OK", role: .cancel) {
                deletionErrorMessage = ""
            }
        } message: {
            Text(deletionErrorMessage)
        }
    }

    private func removeInstallation(_ installation: PartInstallation) async -> Bool {
        let originalError = viewModel.errorMessage
        await viewModel.removeInstallation(installation, helicopterId: helicopterId)

        // Check if a new error was set
        if let error = viewModel.errorMessage, error != originalError {
            // Error occurred - show error alert
            deletionErrorMessage = error
            showingDeletionError = true
            viewModel.errorMessage = nil  // Clear it so it doesn't show in the list
            return false
        }
        return true
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}
