import SwiftUI
import Combine

struct FlightView: View {
    @EnvironmentObject var helicoptersViewModel: HelicoptersViewModel
    @StateObject private var viewModel = FlightViewModel()

    @State private var selectedHelicopterIndex = 0
    @State private var showingHobbsScanner = false
    @State private var showingAddSquawk = false
    @State private var showingSquawkDetails: Squawk? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if helicoptersViewModel.helicopters.isEmpty {
                    // Loading or empty state
                    ProgressView("Loading helicopters...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Aircraft Banner
                    aircraftBanner

                    // Squawks Section
                    squawksSection
                }
            }
            .navigationTitle("Flight Operations")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingHobbsScanner) {
                HobbsScannerView(
                    helicopterId: selectedHelicopter?.id ?? 0,
                    onHobbsScanned: { hours in
                        viewModel.updateHobbsHours(hours: hours, helicopterId: selectedHelicopter?.id ?? 0)
                    }
                )
            }
            .sheet(isPresented: $showingAddSquawk) {
                AddSquawkView(
                    helicopterId: selectedHelicopter?.id ?? 0,
                    onSquawkAdded: {
                        Task {
                            await viewModel.loadSquawks(helicopterId: selectedHelicopter?.id ?? 0)
                        }
                    }
                )
            }
            .sheet(item: $showingSquawkDetails) { squawk in
                SquawkDetailView(
                    squawk: squawk,
                    onSquawkUpdated: {
                        Task {
                            await viewModel.loadSquawks(helicopterId: selectedHelicopter?.id ?? 0)
                        }
                    }
                )
            }
        }
        .task {
            await helicoptersViewModel.loadHelicopters()
            if let helicopter = selectedHelicopter {
                await viewModel.loadSquawks(helicopterId: helicopter.id)
                await viewModel.loadMaintenanceStatus(helicopterId: helicopter.id)
            }
        }
        .onChange(of: selectedHelicopterIndex) { _ in
            Task {
                if let helicopter = selectedHelicopter {
                    await viewModel.loadSquawks(helicopterId: helicopter.id)
                    await viewModel.loadMaintenanceStatus(helicopterId: helicopter.id)
                }
            }
        }
    }

    private var selectedHelicopter: Helicopter? {
        guard !helicoptersViewModel.helicopters.isEmpty else { return nil }
        return helicoptersViewModel.helicopters[selectedHelicopterIndex]
    }

    // MARK: - Aircraft Banner

    private var aircraftBanner: some View {
        VStack(spacing: 12) {
            // Aircraft Selector
            Picker("Aircraft", selection: $selectedHelicopterIndex) {
                ForEach(Array(helicoptersViewModel.helicopters.enumerated()), id: \.element.id) { index, helicopter in
                    Text(helicopter.tailNumber).tag(index)
                }
            }
            .pickerStyle(.menu)
            .font(.title2)
            .fontWeight(.bold)

            // Maintenance Status Indicators
            HStack(spacing: 16) {
                // Oil Change Status
                maintenanceStatusCard(
                    title: "Oil Change",
                    hoursRemaining: viewModel.hoursUntilOilChange,
                    color: maintenanceColor(hoursRemaining: viewModel.hoursUntilOilChange, threshold: 10)
                )

                // Fuel Line AD Status
                maintenanceStatusCard(
                    title: "Fuel Line AD",
                    hoursRemaining: viewModel.hoursUntilFuelLineAD,
                    color: maintenanceColor(hoursRemaining: viewModel.hoursUntilFuelLineAD, threshold: 25)
                )
            }
            .padding(.horizontal)

            // Action Buttons
            HStack(spacing: 12) {
                Button(action: { showingHobbsScanner = true }) {
                    Label("Scan Hobbs", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                Button(action: { showingAddSquawk = true }) {
                    Label("Add Squawk", systemImage: "exclamationmark.triangle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 20)
        .background(Color(.systemGroupedBackground))
    }

    private func maintenanceStatusCard(title: String, hoursRemaining: Double?, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            if let hours = hoursRemaining {
                Text("\(Int(hours))")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(color)

                Text("hours")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Text("--")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }

    private func maintenanceColor(hoursRemaining: Double?, threshold: Double) -> Color {
        guard let hours = hoursRemaining else { return .gray }

        if hours <= 0 {
            return .red
        } else if hours <= threshold {
            return .orange
        } else if hours <= threshold * 2 {
            return .yellow
        } else {
            return .green
        }
    }

    // MARK: - Squawks Section

    private var squawksSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            HStack {
                Text("Squawks")
                    .font(.headline)
                    .padding()

                Spacer()
            }
            .background(Color(.systemGroupedBackground))

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.squawks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    Text("No Squawks")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text("Aircraft is clear for operation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Active Squawks
                        ForEach(activeSquawks) { squawk in
                            squawkRow(squawk: squawk)
                                .onTapGesture {
                                    showingSquawkDetails = squawk
                                }
                        }

                        // Fixed Squawks Header
                        if !fixedSquawks.isEmpty {
                            Text("Fixed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(.systemGroupedBackground))
                        }

                        // Fixed Squawks
                        ForEach(fixedSquawks) { squawk in
                            squawkRow(squawk: squawk)
                                .opacity(0.6)
                                .onTapGesture {
                                    showingSquawkDetails = squawk
                                }
                        }
                    }
                }
            }
        }
    }

    private var activeSquawks: [Squawk] {
        viewModel.squawks.filter { $0.status == .active || $0.status == .deferred }
    }

    private var fixedSquawks: [Squawk] {
        viewModel.squawks.filter { $0.status == .fixed }
    }

    private func squawkRow(squawk: Squawk) -> some View {
        HStack(spacing: 12) {
            // Severity indicator
            Rectangle()
                .fill(severityColor(squawk.severity))
                .frame(width: 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(squawk.title)
                    .font(.headline)

                if let description = squawk.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                HStack {
                    Text(squawk.severity.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(severityColor(squawk.severity).opacity(0.2))
                        .foregroundColor(severityColor(squawk.severity))
                        .cornerRadius(4)

                    Text(formatDate(squawk.reportedAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Spacer()

                    if squawk.status == .fixed {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    private func severityColor(_ severity: SquawkSeverity) -> Color {
        switch severity {
        case .routine:
            return .gray
        case .caution:
            return .orange
        case .urgent:
            return .red
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .short
        displayFormatter.timeStyle = .none
        return displayFormatter.string(from: date)
    }
}

// MARK: - Flight ViewModel

@MainActor
class FlightViewModel: ObservableObject {
    @Published var squawks: [Squawk] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Maintenance status
    @Published var hoursUntilOilChange: Double?
    @Published var hoursUntilFuelLineAD: Double?

    func loadSquawks(helicopterId: Int) async {
        isLoading = true
        errorMessage = nil

        do {
            squawks = try await APIService.shared.getSquawks(helicopterId: helicopterId)
        } catch {
            errorMessage = "Failed to load squawks: \(error.localizedDescription)"
            print("Error loading squawks: \(error)")
        }

        isLoading = false
    }

    func loadMaintenanceStatus(helicopterId: Int) async {
        do {
            let dashboard = try await APIService.shared.getLogbookDashboard(helicopterId: helicopterId)

            // Oil change hours remaining - use dashboard's calculated value
            hoursUntilOilChange = dashboard.hoursUntilOilChange

            // Fuel Line AD - look for it in upcoming maintenance
            if let fuelLineAD = dashboard.upcomingMaintenance.first(where: {
                $0.title.lowercased().contains("fuel line")
            }) {
                hoursUntilFuelLineAD = fuelLineAD.hoursRemaining
            } else {
                hoursUntilFuelLineAD = nil
            }
        } catch {
            print("Error loading maintenance status: \(error)")
        }
    }

    func updateHobbsHours(hours: Double, helicopterId: Int) {
        // This will be implemented when we add the Hobbs scanning functionality
    }
}
