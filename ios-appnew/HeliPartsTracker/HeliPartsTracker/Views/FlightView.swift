import SwiftUI
import Combine

struct FlightView: View {
    @EnvironmentObject var helicoptersViewModel: HelicoptersViewModel
    @StateObject private var viewModel = FlightViewModel()

    @State private var selectedHelicopterIndex = 0
    @State private var showingHobbsScanner = false
    @State private var showingAddSquawk = false
    @State private var showingSquawkDetails: Squawk? = nil
    @State private var showingSquawksSheet = false

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

                    // Flights Section
                    flightsSection
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
            .sheet(isPresented: $showingSquawksSheet) {
                SquawksSheetView(
                    viewModel: viewModel,
                    helicopterId: selectedHelicopter?.id ?? 0,
                    showingAddSquawk: $showingAddSquawk,
                    showingSquawkDetails: $showingSquawkDetails
                )
            }
        }
        .task {
            await helicoptersViewModel.loadHelicopters()
            if let helicopter = selectedHelicopter {
                await viewModel.loadFlights(helicopterId: helicopter.id)
                await viewModel.loadSquawks(helicopterId: helicopter.id)
                await viewModel.loadMaintenanceStatus(helicopterId: helicopter.id)
            }
        }
        .onChange(of: selectedHelicopterIndex) { _ in
            Task {
                if let helicopter = selectedHelicopter {
                    await viewModel.loadFlights(helicopterId: helicopter.id)
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
            // Aircraft Selector - Larger and Bolder
            Picker("Aircraft", selection: $selectedHelicopterIndex) {
                ForEach(Array(helicoptersViewModel.helicopters.enumerated()), id: \.element.id) { index, helicopter in
                    Text(helicopter.tailNumber).tag(index)
                }
            }
            .pickerStyle(.menu)
            .font(.system(size: 32, weight: .heavy))
            .foregroundColor(.primary)

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

            // Action Buttons (Swapped order)
            HStack(spacing: 12) {
                Button(action: { showingAddSquawk = true }) {
                    Label("Add Squawk", systemImage: "exclamationmark.triangle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                Button(action: { showingHobbsScanner = true }) {
                    Label("Scan Hobbs", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal)

            // View Squawks Button
            Button(action: { showingSquawksSheet = true }) {
                HStack {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.headline)
                    Text("View Squawks")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.up")
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .foregroundColor(.primary)
                .cornerRadius(10)
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

    // MARK: - Flights Section

    private var flightsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            HStack {
                Text("Recent Flights")
                    .font(.headline)
                    .padding()

                Spacer()
            }
            .background(Color(.systemGroupedBackground))

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.flights.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "airplane")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No Flights Logged")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text("Scan the Hobbs meter to log a flight")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(viewModel.flights) { flight in
                            flightRow(flight: flight)
                        }
                    }
                }
            }
        }
    }

    private func flightRow(flight: Flight) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let departureTime = flight.departureTime {
                        Text(formatDate(departureTime))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    HStack(spacing: 12) {
                        if let hobbsStart = flight.hobbsStart {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Start")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.1f", hobbsStart))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                        }

                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        if let hobbsEnd = flight.hobbsEnd {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("End")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.1f", hobbsEnd))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                        }

                        if let flightTime = flight.flightTime {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Flight Time")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.1f hrs", flightTime))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                            }
                        }
                    }

                    if let pilotName = flight.pilotName {
                        Text("Pilot: \(pilotName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding()
        }
        .background(Color(.secondarySystemGroupedBackground))
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
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

}

// MARK: - Flight ViewModel

@MainActor
class FlightViewModel: ObservableObject {
    @Published var squawks: [Squawk] = []
    @Published var flights: [Flight] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Maintenance status
    @Published var hoursUntilOilChange: Double?
    @Published var hoursUntilFuelLineAD: Double?

    func loadFlights(helicopterId: Int) async {
        do {
            flights = try await APIService.shared.getFlights(helicopterId: helicopterId, limit: 20)
        } catch {
            print("Error loading flights: \(error)")
        }
    }

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

// MARK: - Squawks Sheet View

struct SquawksSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: FlightViewModel
    let helicopterId: Int
    @Binding var showingAddSquawk: Bool
    @Binding var showingSquawkDetails: Squawk?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Add Squawk Button
                Button(action: {
                    dismiss()
                    showingAddSquawk = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                        Text("Add New Squawk")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()

                // Squawks List
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
                            if !activeSquawks.isEmpty {
                                Section(header: sectionHeader(title: "Active Squawks")) {
                                    ForEach(activeSquawks) { squawk in
                                        squawkRow(squawk: squawk)
                                            .onTapGesture {
                                                dismiss()
                                                showingSquawkDetails = squawk
                                            }
                                    }
                                }
                            }

                            // Fixed Squawks
                            if !fixedSquawks.isEmpty {
                                Section(header: sectionHeader(title: "Fixed")) {
                                    ForEach(fixedSquawks) { squawk in
                                        squawkRow(squawk: squawk)
                                            .opacity(0.6)
                                            .onTapGesture {
                                                dismiss()
                                                showingSquawkDetails = squawk
                                            }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Squawks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
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

    private func sectionHeader(title: String) -> some View {
        Text(title)
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGroupedBackground))
    }

    private func squawkRow(squawk: Squawk) -> some View {
        HStack(spacing: 12) {
            // Severity Indicator
            Circle()
                .fill(severityColor(squawk.severity))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(squawk.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let description = squawk.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                HStack {
                    if let reportedByName = squawk.reportedByName {
                        Text(reportedByName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Text(formatDate(squawk.reportedAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
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
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }
}
