import SwiftUI

struct FilteredLogbookDashboardView: View {
    let helicopterId: Int
    let searchText: String
    @EnvironmentObject var viewModel: LogbookViewModel

    var filteredDashboard: LogbookDashboard? {
        guard let dashboard = viewModel.dashboard else { return nil }

        // If no search text, return full dashboard
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return dashboard
        }

        let query = searchText.lowercased()

        // Filter maintenance logs
        let filteredMaintenance = dashboard.upcomingMaintenance.filter { item in
            item.title.lowercased().contains(query) ||
            (item.category?.lowercased().contains(query) ?? false)
        }

        // Filter life-limited parts
        let filteredParts = dashboard.lifeLimitedParts.filter { part in
            (part.partDescription?.lowercased().contains(query) ?? false) ||
            (part.partNumber?.lowercased().contains(query) ?? false) ||
            (part.partSerialNumber?.lowercased().contains(query) ?? false)
        }

        // Filter fluids
        let filteredFluids = dashboard.recentFluids.filter { fluid in
            fluid.displayFluidType.lowercased().contains(query) ||
            (fluid.notes?.lowercased().contains(query) ?? false)
        }

        // Filter installations
        let filteredInstallations = dashboard.recentInstallations.filter { installation in
            (installation.partNumber?.lowercased().contains(query) ?? false) ||
            (installation.partDescription?.lowercased().contains(query) ?? false) ||
            (installation.notes?.lowercased().contains(query) ?? false)
        }

        // Create filtered dashboard
        return LogbookDashboard(
            helicopter: dashboard.helicopter,
            oilChange: dashboard.oilChange,
            hoursUntilOilChange: dashboard.hoursUntilOilChange,
            upcomingMaintenance: filteredMaintenance,
            lifeLimitedParts: filteredParts,
            recentFluids: filteredFluids,
            recentInstallations: filteredInstallations
        )
    }

    var body: some View {
        LogbookDashboardView(helicopterId: helicopterId, filteredDashboard: filteredDashboard)
            .environmentObject(viewModel)
    }
}

struct LogbookDashboardView: View {
    let helicopterId: Int
    var filteredDashboard: LogbookDashboard? = nil
    @EnvironmentObject var viewModel: LogbookViewModel
    @State private var showingTachScanner = false
    @State private var showingMaintenanceLog = false
    @State private var showingFluidLog = false

    private var dashboardToDisplay: LogbookDashboard? {
        filteredDashboard ?? viewModel.dashboard
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                        .padding()
                } else if let dashboard = dashboardToDisplay {
                    // Current Hours Card
                    CurrentHoursCard(helicopter: dashboard.helicopter, showScanner: $showingTachScanner)

                    // Oil Change Status
                    if let oilChange = dashboard.oilChange, let hoursUntil = dashboard.hoursUntilOilChange {
                        OilChangeStatusCard(hoursUntil: hoursUntil, lastChange: oilChange)
                    }

                    // Upcoming Maintenance
                    if !dashboard.upcomingMaintenance.isEmpty {
                        UpcomingMaintenanceCard(items: dashboard.upcomingMaintenance)
                    } else if filteredDashboard != nil {
                        EmptySearchResultCard(message: "No maintenance items match your search")
                    }

                    // Life Limited Parts
                    if !dashboard.lifeLimitedParts.isEmpty {
                        LifeLimitedPartsCard(parts: dashboard.lifeLimitedParts)
                    } else if filteredDashboard != nil {
                        EmptySearchResultCard(message: "No parts match your search")
                    }

                    // Quick Actions
                    QuickActionsCard(
                        showMaintenanceLog: $showingMaintenanceLog,
                        showFluidLog: $showingFluidLog
                    )

                    // Recent Fluids
                    if !dashboard.recentFluids.isEmpty {
                        RecentFluidsCard(fluids: dashboard.recentFluids)
                    } else if filteredDashboard != nil {
                        EmptySearchResultCard(message: "No fluid logs match your search")
                    }

                    // Recent Part Installations
                    if !dashboard.recentInstallations.isEmpty {
                        RecentInstallationsCard(installations: dashboard.recentInstallations)
                    } else if filteredDashboard != nil {
                        EmptySearchResultCard(message: "No part installations match your search")
                    }
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error) {
                        Task {
                            await viewModel.loadDashboard(helicopterId: helicopterId)
                        }
                    }
                }
            }
            .padding()
        }
        .task {
            if filteredDashboard == nil {
                await viewModel.loadDashboard(helicopterId: helicopterId)
            }
        }
        .refreshable {
            await viewModel.loadDashboard(helicopterId: helicopterId)
        }
        .sheet(isPresented: $showingTachScanner) {
            TachScannerView(helicopterId: helicopterId)
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showingMaintenanceLog) {
            AddMaintenanceLogView(helicopterId: helicopterId)
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showingFluidLog) {
            AddFluidLogView(helicopterId: helicopterId)
                .environmentObject(viewModel)
        }
    }
}

struct CurrentHoursCard: View {
    let helicopter: HelicopterDetail
    @Binding var showScanner: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Current Hours", systemImage: "clock")
                    .font(.headline)
                Spacer()
                Button(action: { showScanner = true }) {
                    Image(systemName: "camera")
                        .font(.title3)
                }
            }

            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "%.1f", helicopter.currentHours))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                Text("hours")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            Text("\(helicopter.tailNumber) • \(helicopter.model)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5)
    }
}

struct OilChangeStatusCard: View {
    let hoursUntil: Double
    let lastChange: MaintenanceLog
    @EnvironmentObject var viewModel: LogbookViewModel
    @State private var selectedLog: MaintenanceLog?

    var statusColor: Color {
        if hoursUntil <= 0 {
            return .red
        } else if hoursUntil <= 10 {
            return .orange
        } else {
            return .green
        }
    }

    var body: some View {
        Button(action: { selectedLog = lastChange }) {
        VStack(alignment: .leading, spacing: 12) {
            Label("Next Oil Change", systemImage: "drop.fill")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(String(format: "%.1f", hoursUntil))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(statusColor)
                        Text("hours")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }

                    if let nextDue = lastChange.nextDueHours {
                        Text("Due at \(String(format: "%.1f", nextDue)) hours")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()

                Image(systemName: hoursUntil <= 10 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(statusColor)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .shadow(color: .black.opacity(0.1), radius: 5)
        .sheet(item: $selectedLog) { log in
            AddMaintenanceLogView(helicopterId: log.helicopterId, existingLog: log)
                .environmentObject(viewModel)
                .id(log.id)
        }
    }
}

struct UpcomingMaintenanceCard: View {
    let items: [UpcomingMaintenance]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Upcoming Maintenance", systemImage: "wrench.and.screwdriver")
                .font(.headline)

            ForEach(items.prefix(3)) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if let hoursRemaining = item.hoursRemaining {
                            Text("\(String(format: "%.1f", hoursRemaining)) hours remaining")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    if let hoursRemaining = item.hoursRemaining {
                        if hoursRemaining <= 10 {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(.vertical, 4)

                if item.id != items.prefix(3).last?.id {
                    Divider()
                }
            }

            if items.count > 3 {
                NavigationLink(destination: MaintenanceListView(helicopterId: items.first?.id ?? 0)) {
                    Text("View All (\(items.count))")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5)
    }
}

struct LifeLimitedPartsCard: View {
    let parts: [LifeLimitedPart]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Life-Limited Parts", systemImage: "timer")
                .font(.headline)

            ForEach(parts.prefix(3)) { part in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(part.partDescription ?? "Part #\(part.partSerialNumber ?? "")")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if let percent = part.percentRemaining {
                            Text("\(String(format: "%.1f", percent))% remaining")
                                .font(.caption)
                                .foregroundColor(percent <= 20 ? .red : .secondary)
                        }
                    }

                    Spacer()

                    if part.isNearExpiration {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(part.isExpired ? .red : .orange)
                    }
                }
                .padding(.vertical, 4)

                if part.id != parts.prefix(3).last?.id {
                    Divider()
                }
            }

            if parts.count > 3 {
                NavigationLink(destination: LifeLimitedPartsListView(helicopterId: parts.first?.helicopterId ?? 0)) {
                    Text("View All (\(parts.count))")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5)
    }
}

struct QuickActionsCard: View {
    @Binding var showMaintenanceLog: Bool
    @Binding var showFluidLog: Bool

    var body: some View {
        VStack(spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Button(action: { showMaintenanceLog = true }) {
                    VStack {
                        Image(systemName: "wrench.fill")
                            .font(.title2)
                        Text("Maintenance")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(10)
                }

                Button(action: { showFluidLog = true }) {
                    VStack {
                        Image(systemName: "drop.fill")
                            .font(.title2)
                        Text("Add Fluid")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5)
    }
}

struct RecentFluidsCard: View {
    let fluids: [FluidLog]
    @EnvironmentObject var viewModel: LogbookViewModel
    @State private var selectedFluid: FluidLog?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Recent Fluid Additions", systemImage: "drop")
                .font(.headline)

            ForEach(fluids.prefix(3)) { fluid in
                Button(action: {
                    selectedFluid = fluid
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(fluid.displayFluidType)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text("\(String(format: "%.1f", fluid.quantity)) \(fluid.unit)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(formatDate(fluid.dateAdded))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())

                if fluid.id != fluids.prefix(3).last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5)
        .sheet(item: $selectedFluid) { fluid in
            AddFluidLogView(helicopterId: fluid.helicopterId, existingLog: fluid)
                .environmentObject(viewModel)
                .id(fluid.id)
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

struct RecentInstallationsCard: View {
    let installations: [PartInstallation]
    @EnvironmentObject var viewModel: LogbookViewModel
    @State private var selectedInstallation: PartInstallation?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Recent Part Installations", systemImage: "wrench.and.screwdriver")
                .font(.headline)

            ForEach(installations.prefix(3)) { installation in
                Button(action: {
                    selectedInstallation = installation
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(installation.partNumber ?? "Unknown Part")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            if let description = installation.partDescription {
                                Text(description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            HStack {
                                Text("Qty: \(installation.quantityInstalled)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                if let username = installation.installedByUsername {
                                    Text("•")
                                        .foregroundColor(.secondary)
                                    Text(username)
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                        }

                        Spacer()

                        Text(formatDate(installation.installationDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())

                if installation.id != installations.prefix(3).last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5)
        .sheet(item: $selectedInstallation) { installation in
            EditInstallationView(installation: installation)
                .environmentObject(viewModel)
                .id(installation.id)
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

struct ErrorView: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button("Retry", action: retryAction)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .padding()
    }
}

struct EmptySearchResultCard: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title)
                .foregroundColor(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// Placeholder views for navigation (to be implemented)
struct MaintenanceListView: View {
    let helicopterId: Int

    var body: some View {
        Text("Maintenance List - Coming Soon")
            .navigationTitle("Maintenance")
    }
}

struct LifeLimitedPartsListView: View {
    let helicopterId: Int

    var body: some View {
        Text("Life Limited Parts - Coming Soon")
            .navigationTitle("Life-Limited Parts")
    }
}
