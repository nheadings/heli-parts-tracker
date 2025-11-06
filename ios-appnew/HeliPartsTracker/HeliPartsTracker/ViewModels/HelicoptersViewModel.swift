import Foundation
import Combine

@MainActor
class HelicoptersViewModel: ObservableObject {
    @Published var helicopters: [Helicopter] = []
    @Published var selectedHelicopter: Helicopter?
    @Published var installedParts: [PartInstallation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiService = APIService.shared

    func loadHelicopters() async {
        isLoading = true
        errorMessage = nil

        do {
            helicopters = try await apiService.getHelicopters()
        } catch {
            errorMessage = "Failed to load helicopters: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func loadHelicopterParts(helicopterId: Int) async {
        isLoading = true
        errorMessage = nil

        do {
            installedParts = try await apiService.getHelicopterParts(id: helicopterId)
            isLoading = false
        } catch {
            print("Error loading helicopter parts: \(error)")
            errorMessage = "Failed to load parts: \(error.localizedDescription)"
            installedParts = []
            isLoading = false
        }
    }

    func installPart(partId: Int, helicopterId: Int, quantity: Int, notes: String?) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            _ = try await apiService.installPart(
                partId: partId,
                helicopterId: helicopterId,
                quantity: quantity,
                notes: notes
            )
            await loadHelicopterParts(helicopterId: helicopterId)
            return true
        } catch {
            errorMessage = "Failed to install part: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    func removeInstallation(_ installation: PartInstallation, helicopterId: Int) async {
        isLoading = true
        errorMessage = nil

        print("DEBUG: Attempting to remove installation ID: \(installation.id)")

        do {
            try await apiService.removeInstallation(id: installation.id)
            print("DEBUG: Successfully removed installation")
            await loadHelicopterParts(helicopterId: helicopterId)
        } catch {
            print("DEBUG: Failed to remove installation - \(error)")
            errorMessage = "Failed to remove installation: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func createHelicopter(_ helicopterData: HelicopterCreate) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            _ = try await apiService.createHelicopter(helicopterData)
            await loadHelicopters()
            isLoading = false
            return true
        } catch {
            errorMessage = "Failed to create helicopter: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    func deleteHelicopter(_ helicopter: Helicopter) async {
        isLoading = true
        errorMessage = nil

        do {
            try await apiService.deleteHelicopter(id: helicopter.id)
            await loadHelicopters()
        } catch {
            errorMessage = "Failed to delete helicopter: \(error.localizedDescription)"
        }

        isLoading = false
    }
}
