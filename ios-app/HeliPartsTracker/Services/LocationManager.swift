import Foundation

class LocationManager: ObservableObject {
    static let shared = LocationManager()

    @Published var locations: [String] = []

    private let locationsKey = "PartLocations"

    init() {
        loadLocations()
    }

    func loadLocations() {
        if let savedLocations = UserDefaults.standard.array(forKey: locationsKey) as? [String] {
            locations = savedLocations.sorted()
        } else {
            // Default locations
            locations = [
                "Main Storage",
                "Warehouse A",
                "Warehouse B",
                "Tool Room",
                "Parts Counter",
                "Shelf 1",
                "Shelf 2",
                "Shelf 3"
            ].sorted()
            saveLocations()
        }
    }

    func saveLocations() {
        UserDefaults.standard.set(locations, forKey: locationsKey)
    }

    func addLocation(_ location: String) {
        let trimmed = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !locations.contains(trimmed) else { return }
        locations.append(trimmed)
        locations.sort()
        saveLocations()
    }

    func removeLocation(_ location: String) {
        locations.removeAll { $0 == location }
        saveLocations()
    }
}
