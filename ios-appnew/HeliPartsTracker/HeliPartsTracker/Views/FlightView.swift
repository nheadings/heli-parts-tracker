import SwiftUI
import Combine

struct FlightView: View {
    @EnvironmentObject var helicoptersViewModel: HelicoptersViewModel
    @StateObject private var viewModel = FlightViewModel()
    @StateObject private var flightTimer = FlightTimerManager()

    @State private var selectedHelicopterIndex = 0
    @State private var showingHobbsScanner = false
    @State private var showingAddSquawk = false
    @State private var showingSquawkDetails: Squawk? = nil
    @State private var showingSquawksSheet = false
    @State private var showingEditFlight = false
    @State private var editingFlight: Flight? = nil
    @State private var prefilledFlightData: EditFlightView.PrefilledFlightData? = nil
    @State private var showingCancelFlightAlert = false
    @State private var flightToDelete: Flight? = nil
    @State private var showingDeleteFlightAlert = false
    @State private var selectedMaintenanceItem: FlightViewMaintenance? = nil

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

                    // Flight Timer Section
                    flightTimerSection

                    // Flights Section
                    flightsSection
                }
            }
            .navigationTitle("Flight Operations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Flight Operations")
                        .font(.system(size: 28, weight: .bold))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if let currentHours = selectedHelicopter?.currentHours, currentHours > 0 {
                        VStack(spacing: 1) {
                            Text("Hobbs")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f", currentHours))
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.blue)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
            .sheet(isPresented: $showingHobbsScanner) {
                HobbsScannerView(
                    helicopterId: selectedHelicopter?.id ?? 0,
                    currentHours: selectedHelicopter?.currentHours ?? 0,
                    onHobbsScanned: { hours in
                        viewModel.updateHobbsHours(hours: hours, helicopterId: selectedHelicopter?.id ?? 0)
                        Task {
                            // Reload everything after Hobbs scan
                            await helicoptersViewModel.loadHelicopters()
                            if let helicopter = selectedHelicopter {
                                await viewModel.loadFlights(helicopterId: helicopter.id)
                                await viewModel.loadMaintenanceStatus(helicopterId: helicopter.id)
                            }
                        }
                    },
                    scanOnly: false,
                    autoOpenCamera: false
                )
            }
            .sheet(isPresented: $showingAddSquawk) {
                AddSquawkView(
                    helicopterId: selectedHelicopter?.id ?? 0,
                    onSquawkAdded: {
                        Task {
                            await viewModel.loadSquawks(helicopterId: selectedHelicopter?.id ?? 0)
                            // Also reload helicopters and flights in case this affected anything
                            await helicoptersViewModel.loadHelicopters()
                            if let helicopter = selectedHelicopter {
                                await viewModel.loadFlights(helicopterId: helicopter.id)
                            }
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
                            // Reload helicopters in case squawk affected anything
                            await helicoptersViewModel.loadHelicopters()
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
            .sheet(isPresented: $showingEditFlight) {
                if let helicopterId = selectedHelicopter?.id {
                    EditFlightView(
                        helicopterId: helicopterId,
                        existingFlight: editingFlight,
                        prefilledData: prefilledFlightData,
                        onSave: {
                            Task {
                                await viewModel.loadFlights(helicopterId: helicopterId)
                                await helicoptersViewModel.loadHelicopters()
                            }
                        }
                    )
                }
            }
            .sheet(item: $selectedMaintenanceItem) { item in
                if let helicopter = selectedHelicopter {
                    AddMaintenanceCompletionView(
                        helicopter: helicopter,
                        maintenanceItem: item,
                        onComplete: {
                            Task {
                                await viewModel.loadMaintenanceStatus(helicopterId: helicopter.id)
                            }
                        }
                    )
                }
            }
        }
        .alert("Cancel Flight?", isPresented: $showingCancelFlightAlert) {
            Button("Cancel Flight", role: .destructive) {
                flightTimer.cancelFlight()
            }
            Button("Keep Flying", role: .cancel) {}
        } message: {
            Text("Are you sure you want to cancel this flight? All flight data will be lost.")
        }
        .alert("Delete Flight?", isPresented: $showingDeleteFlightAlert) {
            Button("Delete", role: .destructive) {
                if let flight = flightToDelete {
                    deleteFlight(flight)
                }
            }
            Button("Cancel", role: .cancel) {
                flightToDelete = nil
            }
        } message: {
            if let flight = flightToDelete {
                if let departureTime = flight.departureTime {
                    Text("Are you sure you want to delete the flight from \(formatDate(departureTime))? This action cannot be undone.")
                } else {
                    Text("Are you sure you want to delete this flight? This action cannot be undone.")
                }
            } else {
                Text("Are you sure you want to delete this flight? This action cannot be undone.")
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
        VStack(spacing: 8) {
            // Aircraft Selector - Larger and Bolder
            Menu {
                ForEach(Array(helicoptersViewModel.helicopters.enumerated()), id: \.element.id) { index, helicopter in
                    Button(action: {
                        selectedHelicopterIndex = index
                    }) {
                        Text(helicopter.tailNumber)
                    }
                }
            } label: {
                HStack {
                    Text(selectedHelicopter?.tailNumber ?? "Select Aircraft")
                        .font(.system(size: 42, weight: .heavy))
                        .foregroundColor(flightTimer.isRunning ? .gray : .blue)
                    if !flightTimer.isRunning {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.secondary)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                }
            }
            .disabled(flightTimer.isRunning)

            if flightTimer.isRunning {
                Text("Cannot switch aircraft in flight")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            // Dynamic Maintenance Status Indicators
            if !viewModel.maintenanceItems.isEmpty {
                HStack(spacing: calculateMaintenanceSpacing(count: viewModel.maintenanceItems.count)) {
                    ForEach(viewModel.maintenanceItems.sorted { $0.displayOrder < $1.displayOrder }) { item in
                        dynamicMaintenanceCard(item: item)
                    }
                }
                .padding(.horizontal)
            }

            // Action Buttons
            HStack(spacing: 12) {
                Button(action: { showingSquawksSheet = true }) {
                    Label("Squawks", systemImage: "exclamationmark.triangle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                Button(action: { startFlight() }) {
                    Label("Start Flight", systemImage: "timer")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(flightTimer.isRunning)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
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

    private func dynamicMaintenanceCard(item: FlightViewMaintenance) -> some View {
        let backgroundColor = Color(hex: item.color)
        let percentageRemaining = (item.hoursRemaining / item.intervalHours) * 100
        let textColor = getTextColorForPercentage(percentageRemaining)

        return VStack(spacing: 4) {
            Text(item.title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text("\(Int(item.hoursRemaining))")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(textColor)

            Text("hours")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(backgroundColor)
        .cornerRadius(12)
        .onTapGesture {
            selectedMaintenanceItem = item
        }
    }

    private func getTextColorForPercentage(_ percentage: Double) -> Color {
        // Seamless color transition based on percentage remaining
        // 100-75%: Green
        // 75-50%: Green to Yellow
        // 50-25%: Yellow to Orange
        // 25-0%: Orange to Red
        // <0%: Red

        if percentage < 0 {
            return .red
        } else if percentage <= 25 {
            // Red to Orange (0-25%)
            let normalizedPercent = percentage / 25.0
            return interpolateColor(from: .red, to: Color(red: 1.0, green: 0.6, blue: 0.0), percentage: normalizedPercent)
        } else if percentage <= 50 {
            // Orange to Yellow (25-50%)
            let normalizedPercent = (percentage - 25.0) / 25.0
            return interpolateColor(from: Color(red: 1.0, green: 0.6, blue: 0.0), to: .yellow, percentage: normalizedPercent)
        } else if percentage <= 75 {
            // Yellow to Light Green (50-75%)
            let normalizedPercent = (percentage - 50.0) / 25.0
            return interpolateColor(from: .yellow, to: Color(red: 0.6, green: 1.0, blue: 0.4), percentage: normalizedPercent)
        } else {
            // Light Green to Green (75-100%)
            let normalizedPercent = (percentage - 75.0) / 25.0
            return interpolateColor(from: Color(red: 0.6, green: 1.0, blue: 0.4), to: .green, percentage: normalizedPercent)
        }
    }

    private func interpolateColor(from: Color, to: Color, percentage: Double) -> Color {
        let fromComponents = UIColor(from).cgColor.components ?? [0, 0, 0, 1]
        let toComponents = UIColor(to).cgColor.components ?? [0, 0, 0, 1]

        let r = fromComponents[0] + (toComponents[0] - fromComponents[0]) * percentage
        let g = fromComponents[1] + (toComponents[1] - fromComponents[1]) * percentage
        let b = fromComponents[2] + (toComponents[2] - fromComponents[2]) * percentage

        return Color(red: r, green: g, blue: b)
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

    private func maintenanceColorFromHex(hex: String, hoursRemaining: Double, threshold: Int) -> Color {
        let baseColor = Color(hex: hex)

        // Apply opacity based on urgency
        if hoursRemaining <= 0 {
            return .red // Override to red for overdue
        } else if hoursRemaining <= Double(threshold) {
            return baseColor // Full color for warning zone
        } else if hoursRemaining <= Double(threshold) * 2 {
            return baseColor.opacity(0.7) // Slightly faded for approaching
        } else {
            return baseColor.opacity(0.5) // Faded for plenty of time
        }
    }

    private func calculateMaintenanceSpacing(count: Int) -> CGFloat {
        // Adjust spacing based on number of items to fit on screen
        switch count {
        case 1...2:
            return 16
        case 3:
            return 12
        case 4:
            return 8
        case 5:
            return 6
        default:
            return 6
        }
    }

    // MARK: - Flight Timer Section

    private var flightTimerSection: some View {
        VStack(spacing: 0) {
            if flightTimer.isRunning {
                // Active Timer UI
                VStack(spacing: 12) {
                    Text("FLIGHT IN PROGRESS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .cornerRadius(8)

                    Text(flightTimer.formattedElapsedTime())
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)

                    if let startHobbs = flightTimer.startHobbs {
                        Text("Start Hobbs: \(String(format: "%.1f", startHobbs))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 16) {
                        if flightTimer.isPaused {
                            Button(action: {
                                flightTimer.resumeFlight()
                            }) {
                                Label("Resume", systemImage: "play.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        } else {
                            Button(action: {
                                flightTimer.pauseFlight()
                            }) {
                                Label("Pause", systemImage: "pause.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }

                        Button(action: {
                            endFlight()
                        }) {
                            Label("End Flight", systemImage: "stop.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)

                    Button(action: {
                        showingCancelFlightAlert = true
                    }) {
                        Text("Cancel Flight")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
            }

            Divider()
        }
    }

    private func startFlight() {
        guard let helicopter = selectedHelicopter else { return }
        let currentHobbs = helicopter.currentHours ?? 0
        flightTimer.startFlight(helicopterId: helicopter.id, currentHobbs: currentHobbs)
    }

    private func endFlight() {
        guard let flightData = flightTimer.endFlight(),
              let helicopter = selectedHelicopter else { return }

        let departureDate = Date().addingTimeInterval(-flightData.elapsedTime)

        prefilledFlightData = EditFlightView.PrefilledFlightData(
            hobbsStart: flightData.startHobbs,
            flightTimeHours: flightData.elapsedTime / 3600.0,
            departureTime: departureDate,
            arrivalTime: Date()
        )
        editingFlight = nil
        showingEditFlight = true
    }

    private func deleteFlight(_ flight: Flight) {
        Task {
            do {
                try await APIService.shared.deleteFlight(id: flight.id)

                // Reload flights and helicopters after deletion
                if let helicopter = selectedHelicopter {
                    await viewModel.loadFlights(helicopterId: helicopter.id)
                    await helicoptersViewModel.loadHelicopters()
                }

                flightToDelete = nil
            } catch {
                print("Error deleting flight: \(error)")
                // Could add error alert here if needed
            }
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
                List {
                    ForEach(viewModel.flights) { flight in
                        flightRow(flight: flight)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingFlight = flight
                                prefilledFlightData = nil
                                showingEditFlight = true
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    flightToDelete = flight
                                    showingDeleteFlightAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
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

    // Dynamic maintenance status
    @Published var maintenanceItems: [FlightViewMaintenance] = []

    // Legacy maintenance status (for backwards compatibility)
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

            // Load dynamic maintenance items
            maintenanceItems = dashboard.flightViewMaintenance

            // Legacy support - keep old fields for compatibility
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
