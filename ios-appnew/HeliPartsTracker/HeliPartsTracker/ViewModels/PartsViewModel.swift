import Foundation
import Combine

@MainActor
class PartsViewModel: ObservableObject {
    @Published var parts: [Part] = []
    @Published var lowStockParts: [Part] = []
    @Published var searchQuery: String = ""
    @Published var lifeLimitedFilter: LifeLimitedFilter = .all
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiService = APIService.shared

    enum LifeLimitedFilter: String, CaseIterable {
        case all = "All Parts"
        case lifeLimitedOnly = "Life-Limited Only"
        case nonLifeLimited = "Non Life-Limited"
    }

    var filteredParts: [Part] {
        var filtered = parts

        // Apply life-limited filter
        switch lifeLimitedFilter {
        case .all:
            break
        case .lifeLimitedOnly:
            filtered = filtered.filter { $0.isLifeLimited == true }
        case .nonLifeLimited:
            filtered = filtered.filter { $0.isLifeLimited != true }
        }

        // Apply search filter
        if !searchQuery.isEmpty {
            filtered = filtered.filter { part in
                part.partNumber.lowercased().contains(searchQuery.lowercased()) ||
                part.description.lowercased().contains(searchQuery.lowercased())
            }
        }

        return filtered
    }

    func loadParts() async {
        isLoading = true
        errorMessage = nil

        do {
            parts = try await apiService.getParts()
        } catch {
            errorMessage = "Failed to load parts: \(error.localizedDescription)"
        }

        isLoading = false
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
