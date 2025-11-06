import SwiftUI
import Combine

struct LogbookView: View {
    @StateObject private var viewModel = LogbookViewModel()
    @EnvironmentObject var helicoptersViewModel: HelicoptersViewModel
    @State private var selectedHelicopterId: Int?
    @State private var searchText = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Helicopter Picker
                VStack(spacing: 12) {
                    if helicoptersViewModel.helicopters.isEmpty {
                        if helicoptersViewModel.isLoading {
                            ProgressView("Loading helicopters...")
                                .padding()
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.title)
                                    .foregroundColor(.orange)
                                Text("No helicopters available")
                                    .font(.headline)
                                Text("Add a helicopter in the Helicopters tab")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                        }
                    } else {
                        Menu {
                            ForEach(helicoptersViewModel.helicopters) { helicopter in
                                Button(action: {
                                    selectedHelicopterId = helicopter.id
                                    Task {
                                        await viewModel.loadDashboard(helicopterId: helicopter.id)
                                    }
                                }) {
                                    HStack {
                                        Text("\(helicopter.tailNumber) - \(helicopter.model)")
                                        if selectedHelicopterId == helicopter.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "helicopter")
                                    .foregroundColor(.blue)
                                if let selectedId = selectedHelicopterId,
                                   let selected = helicoptersViewModel.helicopters.first(where: { $0.id == selectedId }) {
                                    Text("\(selected.tailNumber) - \(selected.model)")
                                        .foregroundColor(.primary)
                                } else {
                                    Text("Select Helicopter")
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                    }

                    // Search Bar
                    if selectedHelicopterId != nil {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search parts or descriptions...", text: $searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                }
                .padding()
                .background(Color(.systemBackground))

                Divider()

                // Dashboard Content
                if let helicopterId = selectedHelicopterId {
                    FilteredLogbookDashboardView(
                        helicopterId: helicopterId,
                        searchText: searchText
                    )
                    .environmentObject(viewModel)
                } else {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)

                        Text("Select a Helicopter")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Choose a helicopter from the dropdown above to view its logbook")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Logbook")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            await helicoptersViewModel.loadHelicopters()
        }
    }
}

@MainActor
class LogbookViewModel: ObservableObject {
    @Published var dashboard: LogbookDashboard?
    @Published var hoursHistory: [HelicopterHours] = []
    @Published var maintenanceLogs: [MaintenanceLog] = []
    @Published var fluidLogs: [FluidLog] = []
    @Published var lifeLimitedParts: [LifeLimitedPart] = []
    @Published var maintenanceSchedules: [MaintenanceSchedule] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadDashboard(helicopterId: Int) async {
        await MainActor.run { isLoading = true }

        do {
            let data = try await APIService.shared.getLogbookDashboard(helicopterId: helicopterId)
            await MainActor.run {
                self.dashboard = data
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load dashboard: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    func loadHoursHistory(helicopterId: Int) async {
        do {
            let data = try await APIService.shared.getHelicopterHours(helicopterId: helicopterId)
            await MainActor.run {
                self.hoursHistory = data.history
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load hours history: \(error.localizedDescription)"
            }
        }
    }

    func updateHours(helicopterId: Int, hours: Double, photoUrl: String?, ocrConfidence: Double?, entryMethod: String, notes: String?) async throws {
        let hoursData = HelicopterHoursCreate(
            hours: hours,
            photoUrl: photoUrl,
            ocrConfidence: ocrConfidence,
            entryMethod: entryMethod,
            notes: notes
        )

        let _ = try await APIService.shared.updateHelicopterHours(helicopterId: helicopterId, hours: hoursData)

        // Reload dashboard and history
        await loadDashboard(helicopterId: helicopterId)
        await loadHoursHistory(helicopterId: helicopterId)
    }

    func loadMaintenanceLogs(helicopterId: Int) async {
        do {
            let logs = try await APIService.shared.getMaintenanceLogs(helicopterId: helicopterId)
            await MainActor.run {
                self.maintenanceLogs = logs
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load maintenance logs: \(error.localizedDescription)"
            }
        }
    }

    func createMaintenanceLog(helicopterId: Int, log: MaintenanceLogCreate) async throws {
        let _ = try await APIService.shared.createMaintenanceLog(helicopterId: helicopterId, log: log)
        await loadMaintenanceLogs(helicopterId: helicopterId)
        await loadDashboard(helicopterId: helicopterId)
    }

    func updateMaintenanceLog(helicopterId: Int, id: Int, log: MaintenanceLogCreate) async throws {
        let _ = try await APIService.shared.updateMaintenanceLog(id: id, log: log)
        await loadMaintenanceLogs(helicopterId: helicopterId)
        await loadDashboard(helicopterId: helicopterId)
    }

    func loadFluidLogs(helicopterId: Int) async {
        do {
            let logs = try await APIService.shared.getFluidLogs(helicopterId: helicopterId)
            await MainActor.run {
                self.fluidLogs = logs
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load fluid logs: \(error.localizedDescription)"
            }
        }
    }

    func createFluidLog(helicopterId: Int, log: FluidLogCreate) async throws {
        let _ = try await APIService.shared.createFluidLog(helicopterId: helicopterId, log: log)
        await loadFluidLogs(helicopterId: helicopterId)
    }

    func updateFluidLog(id: Int, log: FluidLogCreate) async throws {
        let _ = try await APIService.shared.updateFluidLog(id: id, log: log)
        // Dashboard reload is handled by the caller
    }

    func deleteFluidLog(id: Int, helicopterId: Int) async throws {
        try await APIService.shared.deleteFluidLog(id: id)
        // Dashboard reload handled by caller with delay
    }

    func deleteMaintenanceLog(id: Int, helicopterId: Int) async throws {
        try await APIService.shared.deleteMaintenanceLog(id: id)
        // Dashboard reload handled by caller with delay
    }

    func deleteInstallation(id: Int, helicopterId: Int) async throws {
        try await APIService.shared.removeInstallation(id: id)
        // Dashboard reload handled by caller with delay
    }

    func loadLifeLimitedParts(helicopterId: Int) async {
        do {
            let parts = try await APIService.shared.getLifeLimitedParts(helicopterId: helicopterId)
            await MainActor.run {
                self.lifeLimitedParts = parts
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load life-limited parts: \(error.localizedDescription)"
            }
        }
    }

    func loadSchedules(helicopterId: Int) async {
        do {
            let schedules = try await APIService.shared.getHelicopterSchedules(helicopterId: helicopterId)
            await MainActor.run {
                self.maintenanceSchedules = schedules
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load schedules: \(error.localizedDescription)"
            }
        }
    }
}
