import Foundation

struct Helicopter: Codable, Identifiable, Hashable {
    let id: Int
    let tailNumber: String
    let model: String
    let manufacturer: String?
    let yearManufactured: Int?
    let serialNumber: String?
    let status: String?
    let currentHours: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case tailNumber = "tail_number"
        case model, manufacturer
        case yearManufactured = "year_manufactured"
        case serialNumber = "serial_number"
        case status
        case currentHours = "current_hours"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        tailNumber = try container.decode(String.self, forKey: .tailNumber)
        model = try container.decode(String.self, forKey: .model)
        manufacturer = try container.decodeIfPresent(String.self, forKey: .manufacturer)
        yearManufactured = try container.decodeIfPresent(Int.self, forKey: .yearManufactured)
        serialNumber = try container.decodeIfPresent(String.self, forKey: .serialNumber)
        status = try container.decodeIfPresent(String.self, forKey: .status)

        // Handle current_hours as either String or Double
        if let hoursString = try? container.decodeIfPresent(String.self, forKey: .currentHours) {
            currentHours = Double(hoursString)
        } else {
            currentHours = try container.decodeIfPresent(Double.self, forKey: .currentHours)
        }
    }
}

struct PartInstallation: Codable, Identifiable, Hashable {
    let id: Int
    let partId: Int?
    let helicopterId: Int?
    let quantityInstalled: Int
    let installationDate: String
    let notes: String?
    let installedBy: String?
    let partNumber: String?
    let partDescription: String?
    let hoursAtInstallation: String?
    let serialNumber: String?
    let installationStatus: String?
    let installedByUsername: String?
    let installedByName: String?

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: PartInstallation, rhs: PartInstallation) -> Bool {
        lhs.id == rhs.id
    }

    enum CodingKeys: String, CodingKey {
        case id = "installation_id"
        case partId = "part_id"
        case helicopterId = "helicopter_id"
        case quantityInstalled = "quantity_installed"
        case installationDate = "installation_date"
        case notes = "installation_notes"
        case installedBy = "installed_by"
        case partNumber = "part_number"
        case partDescription = "description"
        case hoursAtInstallation = "hours_at_installation"
        case serialNumber = "serial_number"
        case installationStatus = "installation_status"
        case installedByUsername = "installed_by_username"
        case installedByName = "installed_by_name"
    }

    // Additional keys for alternate field names
    enum AlternateKeys: String, CodingKey {
        case id
        case notes
        case status
    }

    init(from decoder: Decoder) throws {
        // Try main container first
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let altContainer = try? decoder.container(keyedBy: AlternateKeys.self)

        // Handle id field (can be "installation_id" or "id")
        if let installationId = try? container.decodeIfPresent(Int.self, forKey: .id) {
            id = installationId
        } else if let regularId = try? altContainer?.decode(Int.self, forKey: .id) {
            id = regularId
        } else {
            throw DecodingError.keyNotFound(CodingKeys.id, DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Could not find id or installation_id"
            ))
        }

        partId = try? container.decodeIfPresent(Int.self, forKey: .partId)
        helicopterId = try? container.decodeIfPresent(Int.self, forKey: .helicopterId)

        // quantityInstalled is required
        quantityInstalled = try container.decode(Int.self, forKey: .quantityInstalled)

        // installationDate is required
        installationDate = try container.decode(String.self, forKey: .installationDate)

        // Handle notes field (can be "installation_notes" or "notes")
        if let installationNotes = try? container.decodeIfPresent(String.self, forKey: .notes) {
            notes = installationNotes
        } else {
            notes = try? altContainer?.decodeIfPresent(String.self, forKey: .notes)
        }

        installedBy = try? container.decodeIfPresent(String.self, forKey: .installedBy)
        partNumber = try? container.decodeIfPresent(String.self, forKey: .partNumber)
        partDescription = try? container.decodeIfPresent(String.self, forKey: .partDescription)
        hoursAtInstallation = try? container.decodeIfPresent(String.self, forKey: .hoursAtInstallation)
        serialNumber = try? container.decodeIfPresent(String.self, forKey: .serialNumber)

        // Handle status field (can be "installation_status" or "status")
        if let instStatus = try? container.decodeIfPresent(String.self, forKey: .installationStatus) {
            installationStatus = instStatus
        } else {
            installationStatus = try? altContainer?.decodeIfPresent(String.self, forKey: .status)
        }

        installedByUsername = try? container.decodeIfPresent(String.self, forKey: .installedByUsername)
        installedByName = try? container.decodeIfPresent(String.self, forKey: .installedByName)
    }
}

struct HelicopterCreate: Codable {
    let tailNumber: String
    let model: String
    let manufacturer: String?
    let yearManufactured: Int?
    let serialNumber: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case tailNumber = "tail_number"
        case model
        case manufacturer
        case yearManufactured = "year_manufactured"
        case serialNumber = "serial_number"
        case status
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tailNumber, forKey: .tailNumber)
        try container.encode(model, forKey: .model)
        // Explicitly encode nil values as null
        try container.encode(manufacturer, forKey: .manufacturer)
        try container.encode(yearManufactured, forKey: .yearManufactured)
        try container.encode(serialNumber, forKey: .serialNumber)
        try container.encode(status, forKey: .status)
    }
}
