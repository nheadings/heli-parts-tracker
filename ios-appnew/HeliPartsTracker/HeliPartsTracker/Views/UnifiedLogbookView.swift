import SwiftUI
import Combine

struct UnifiedLogbookView: View {
    @EnvironmentObject var helicoptersViewModel: HelicoptersViewModel
    @StateObject private var viewModel = UnifiedLogbookViewModel()

    @State private var selectedHelicopterId: String = "all"
    @State private var selectedCategories: Set<Int> = []
    @State private var dateRange: DateRangeOption = .all
    @State private var customStartDate = Date().addingTimeInterval(-30 * 24 * 3600)
    @State private var customEndDate = Date()
    @State private var searchText = ""
    @State private var showingFilters = true
    @State private var showingCategoryPicker = false
    @State private var showingDatePicker = false
    @State private var selectedEntry: LogbookEntry? = nil
    @State private var showingAddEntry = false
    @State private var isRefreshing = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filters Section
                if showingFilters {
                    filterSection
                }

                // Search Bar
                searchSection

                // Entries List
                if viewModel.isLoading && viewModel.entries.isEmpty {
                    ProgressView("Loading entries...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.entries.isEmpty {
                    emptyState
                } else {
                    entriesList
                }
            }
            .navigationTitle("Logbook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Menu {
                        Button(action: {
                            selectedHelicopterId = "all"
                        }) {
                            Text("All Aircraft")
                        }
                        ForEach(helicoptersViewModel.helicopters) { heli in
                            Button(action: {
                                selectedHelicopterId = String(heli.id)
                            }) {
                                Text(heli.tailNumber)
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedHelicopterId == "all" ? "All Aircraft" : helicoptersViewModel.helicopters.first(where: { String($0.id) == selectedHelicopterId })?.tailNumber ?? "Select Aircraft")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.blue)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingFilters.toggle() }) {
                        Image(systemName: showingFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .foregroundColor(.blue)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddEntry = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .task {
            await helicoptersViewModel.loadHelicopters()
            await viewModel.loadCategories()
            await loadEntries()
        }
        .onChange(of: selectedHelicopterId) {
            Task {
                await loadEntries()
            }
        }
        .sheet(item: $selectedEntry) { entry in
            LogbookEntryDetailView(entry: entry, onUpdate: {
                Task {
                    await loadEntries()
                }
            })
            .environmentObject(helicoptersViewModel)
            .environmentObject(viewModel)
        }
        .sheet(isPresented: $showingAddEntry) {
            AddLogbookEntryView(
                defaultHelicopterId: selectedHelicopterId == "all" ? nil : Int(selectedHelicopterId),
                defaultCategoryId: nil,
                defaultDescription: nil,
                onSave: {
                    Task {
                        await loadEntries()
                    }
                }
            )
            .environmentObject(helicoptersViewModel)
            .environmentObject(viewModel)
        }
    }

    // MARK: - Filter Section

    private var filterSection: some View {
        VStack(spacing: 12) {
            // Category Filter
            HStack {
                Text("Categories:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { showingCategoryPicker = true }) {
                    HStack {
                        if selectedCategories.isEmpty {
                            Text("All")
                        } else if selectedCategories.count == viewModel.categories.count {
                            Text("All")
                        } else {
                            Text("\(selectedCategories.count) selected")
                        }
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
            }

            // Date Range Filter
            HStack {
                Text("Date Range:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Picker("Date Range", selection: $dateRange) {
                    ForEach(DateRangeOption.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: dateRange) {
                    if dateRange == .custom {
                        showingDatePicker = true
                    } else {
                        Task { await loadEntries() }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .sheet(isPresented: $showingCategoryPicker) {
            categoryPickerSheet
        }
        .sheet(isPresented: $showingDatePicker) {
            customDatePickerSheet
        }
    }

    private var categoryPickerSheet: some View {
        NavigationView {
            List {
                Button(action: {
                    if selectedCategories.count == viewModel.categories.count {
                        selectedCategories = []
                    } else {
                        selectedCategories = Set(viewModel.categories.map { $0.id })
                    }
                }) {
                    HStack {
                        Text("All")
                        Spacer()
                        if selectedCategories.isEmpty || selectedCategories.count == viewModel.categories.count {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }

                ForEach(viewModel.categories) { category in
                    Button(action: {
                        if selectedCategories.contains(category.id) {
                            selectedCategories.remove(category.id)
                        } else {
                            selectedCategories.insert(category.id)
                        }
                    }) {
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundColor(Color(hex: category.color))
                            Text(category.name)
                            Spacer()
                            if selectedCategories.contains(category.id) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("Select Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingCategoryPicker = false
                        Task { await loadEntries() }
                    }
                }
            }
        }
    }

    private var customDatePickerSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                DatePicker("Start Date", selection: $customStartDate, displayedComponents: .date)
                DatePicker("End Date", selection: $customEndDate, displayedComponents: .date)
                Spacer()
            }
            .padding()
            .navigationTitle("Custom Date Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        showingDatePicker = false
                        Task { await loadEntries() }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dateRange = .all
                        showingDatePicker = false
                    }
                }
            }
        }
    }

    // MARK: - Search Section

    private var searchSection: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search entries...", text: $searchText)
                .textFieldStyle(.plain)
                .onChange(of: searchText) {
                    Task {
                        try? await Task.sleep(nanoseconds: 300_000_000) // Debounce
                        await loadEntries()
                    }
                }
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Entries List

    private var entriesList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.entries) { entry in
                    LogbookEntryRow(entry: entry)
                        .onTapGesture {
                            selectedEntry = entry
                        }
                }

                if viewModel.hasMore {
                    ProgressView()
                        .padding()
                        .onAppear {
                            Task {
                                await viewModel.loadMore(
                                    helicopterId: selectedHelicopterId,
                                    categoryIds: categoryIdsString,
                                    startDate: startDateString,
                                    endDate: endDateString,
                                    search: searchText.isEmpty ? nil : searchText
                                )
                            }
                        }
                }
            }
            .padding(.horizontal)
        }
        .refreshable {
            await loadEntries()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Entries Found")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Try adjusting your filters or search")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Helpers

    private func loadEntries() async {
        await viewModel.loadEntries(
            helicopterId: selectedHelicopterId,
            categoryIds: categoryIdsString,
            startDate: startDateString,
            endDate: endDateString,
            search: searchText.isEmpty ? nil : searchText
        )
    }

    private var categoryIdsString: String? {
        if selectedCategories.isEmpty || selectedCategories.count == viewModel.categories.count {
            return "all"
        }
        return selectedCategories.map { String($0) }.joined(separator: ",")
    }

    private var startDateString: String? {
        guard dateRange != .all else { return nil }

        let formatter = ISO8601DateFormatter()
        let calendar = Calendar.current

        switch dateRange {
        case .oneDay:
            return formatter.string(from: calendar.startOfDay(for: Date()))
        case .twoDays:
            let date = calendar.date(byAdding: .day, value: -1, to: Date())!
            return formatter.string(from: calendar.startOfDay(for: date))
        case .week:
            let date = calendar.date(byAdding: .day, value: -7, to: Date())!
            return formatter.string(from: calendar.startOfDay(for: date))
        case .custom:
            return formatter.string(from: calendar.startOfDay(for: customStartDate))
        case .all:
            return nil
        }
    }

    private var endDateString: String? {
        guard dateRange == .custom else { return nil }
        let formatter = ISO8601DateFormatter()
        let calendar = Calendar.current
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: customEndDate)!
        return formatter.string(from: endOfDay)
    }
}

// MARK: - Date Range Option

enum DateRangeOption: String, CaseIterable {
    case oneDay = "1_day"
    case twoDays = "2_days"
    case week = "week"
    case custom = "custom"
    case all = "all"

    var displayName: String {
        switch self {
        case .oneDay: return "1 Day"
        case .twoDays: return "2 Days"
        case .week: return "Week"
        case .custom: return "Custom"
        case .all: return "All"
        }
    }
}

// MARK: - Entry Row

struct LogbookEntryRow: View {
    let entry: LogbookEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                // Category Icon
                Image(systemName: entry.categoryIcon)
                    .font(.title2)
                    .foregroundColor(Color(hex: entry.categoryColor))
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    // Header: Category + Tail Number + Date
                    HStack {
                        Text(entry.categoryName)
                            .font(.headline)
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(entry.tailNumber)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatDate(entry.eventDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Description
                    Text(entry.description)
                        .font(.body)
                        .lineLimit(2)

                    // Details Row
                    HStack(spacing: 12) {
                        if let hours = entry.hoursAtEvent {
                            Label(String(format: "%.1f hrs", hours), systemImage: "clock")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if let cost = entry.cost {
                            Label(String(format: "$%.2f", cost), systemImage: "dollarsign.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if let attachmentCount = entry.attachmentCount, attachmentCount > 0 {
                            Label("\(attachmentCount)", systemImage: "paperclip")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if let performer = entry.performedByName ?? entry.performedByUsername {
                            Text(performer)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Notes preview
                    if let notes = entry.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .italic()
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
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
}

// MARK: - ViewModel

@MainActor
class UnifiedLogbookViewModel: ObservableObject {
    @Published var entries: [LogbookEntry] = []
    @Published var categories: [LogbookCategory] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasMore = false

    private var currentOffset = 0
    private let pageSize = 100

    func loadCategories() async {
        do {
            categories = try await APIService.shared.getLogbookCategories()
        } catch {
            errorMessage = "Failed to load categories: \(error.localizedDescription)"
        }
    }

    func loadEntries(helicopterId: String? = nil, categoryIds: String? = nil, startDate: String? = nil, endDate: String? = nil, search: String? = nil) async {
        isLoading = true
        currentOffset = 0

        do {
            entries = try await APIService.shared.getLogbookEntries(
                helicopterId: helicopterId,
                categoryIds: categoryIds,
                startDate: startDate,
                endDate: endDate,
                search: search,
                limit: pageSize,
                offset: 0
            )
            hasMore = entries.count >= pageSize
        } catch {
            errorMessage = "Failed to load entries: \(error.localizedDescription)"
            entries = []
        }

        isLoading = false
    }

    func loadMore(helicopterId: String? = nil, categoryIds: String? = nil, startDate: String? = nil, endDate: String? = nil, search: String? = nil) async {
        guard !isLoading && hasMore else { return }

        isLoading = true
        currentOffset += pageSize

        do {
            let newEntries = try await APIService.shared.getLogbookEntries(
                helicopterId: helicopterId,
                categoryIds: categoryIds,
                startDate: startDate,
                endDate: endDate,
                search: search,
                limit: pageSize,
                offset: currentOffset
            )
            entries.append(contentsOf: newEntries)
            hasMore = newEntries.count >= pageSize
        } catch {
            errorMessage = "Failed to load more entries: \(error.localizedDescription)"
        }

        isLoading = false
    }
}
