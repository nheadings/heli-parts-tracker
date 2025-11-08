import Foundation
import Combine

@MainActor
class PartsViewModel: ObservableObject {
    @Published var parts: [Part] = []
    @Published var lowStockParts: [Part] = []
    @Published var searchQuery: String = "" {
        didSet {
            searchSubject.send(searchQuery)
        }
    }
    @Published var lifeLimitedFilter: LifeLimitedFilter = .all {
        didSet {
            performSearch()
        }
    }
    @Published var inStockOnly: Bool = false {
        didSet {
            performSearch()
        }
    }
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchHint: String = "Type to search 200,000+ parts..."
    @Published var totalResults: Int = 0

    private let apiService = APIService.shared
    private var searchSubject = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()
    private var currentSearchTask: Task<Void, Never>?

    enum LifeLimitedFilter: String, CaseIterable {
        case all = "All Parts"
        case lifeLimitedOnly = "Life-Limited Only"
        case nonLifeLimited = "Non Life-Limited"
    }

    init() {
        // Debounce search input - wait 300ms after user stops typing
        searchSubject
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.performSearch()
            }
            .store(in: &cancellables)
    }

    var filteredParts: [Part] {
        // Server does all filtering now, just return the parts
        return parts
    }

    private func performSearch() {
        // Cancel any existing search
        currentSearchTask?.cancel()

        // If search query is empty, clear results
        guard !searchQuery.isEmpty || lifeLimitedFilter != .all || inStockOnly else {
            parts = []
            totalResults = 0
            searchHint = "Type to search 200,000+ parts..."
            return
        }

        currentSearchTask = Task {
            isLoading = true
            errorMessage = nil

            do {
                let lifeLimitedValue: String? = {
                    switch lifeLimitedFilter {
                    case .lifeLimitedOnly: return "true"
                    case .nonLifeLimited: return "false"
                    case .all: return nil
                    }
                }()

                let response = try await apiService.searchParts(
                    query: searchQuery,
                    inStock: inStockOnly ? true : nil,
                    lifeLimited: lifeLimitedValue,
                    limit: 100,
                    offset: 0
                )

                guard !Task.isCancelled else { return }

                parts = response.parts ?? []
                totalResults = response.total ?? 0

                if parts.isEmpty && !searchQuery.isEmpty {
                    searchHint = "No parts found matching '\(searchQuery)'"
                } else if let total = response.total, parts.count < total {
                    searchHint = "Showing \(parts.count) of \(total) results"
                } else {
                    searchHint = "Found \(parts.count) part\(parts.count == 1 ? "" : "s")"
                }
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = "Search failed: \(error.localizedDescription)"
                searchHint = "Search error occurred"
            }

            isLoading = false
        }
    }

    func loadParts(forceReload: Bool = false) async {
        // Deprecated - do nothing, search is now the primary method
        return
    }

    func loadPartsIfNeeded() async {
        // Do nothing - we start with empty list until user searches
        return
    }

    func refreshParts() async {
        performSearch()
    }

    func loadLowStockParts() async {
        do {
            lowStockParts = try await apiService.getLowStockParts()
        } catch {
            errorMessage = "Failed to load low stock parts: \(error.localizedDescription)"
        }
    }

    func createPart(_ part: PartCreate) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            _ = try await apiService.createPart(part)
            await loadParts()
            return true
        } catch {
            errorMessage = "Failed to create part: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    func updatePart(id: Int, partData: PartCreate) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            _ = try await apiService.updatePart(id: id, partData)
            await loadParts()
            isLoading = false
            return true
        } catch {
            errorMessage = "Failed to update part: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    func deletePart(_ part: Part) async {
        isLoading = true
        errorMessage = nil

        do {
            try await apiService.deletePart(id: part.id)
            await loadParts()
        } catch {
            errorMessage = "Failed to delete part: \(error.localizedDescription)"
        }

        isLoading = false
    }
}
