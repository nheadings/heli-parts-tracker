import Foundation

// MARK: - Flight Model

struct Flight: Codable, Identifiable, Hashable {
    let id: Int
    let helicopterId: Int
    let pilotId: Int?
    let hobbsStart: Double?
    let hobbsEnd: Double?
    let flightTime: Double?
    let departureTime: String?
    let arrivalTime: String?
    let hobbsPhotoUrl: String?
    let ocrConfidence: Double?
    let notes: String?
    let createdAt: String?
    let updatedAt: String?

    // Additional fields from JOIN
    let pilotUsername: String?
    let pilotName: String?
    let tailNumber: String?

    let tachTime: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case helicopterId = "helicopter_id"
        case pilotId = "pilot_id"
        case hobbsStart = "hobbs_start"
        case hobbsEnd = "hobbs_end"
        case flightTime = "flight_time"
        case tachTime = "tach_time"
        case departureTime = "departure_time"
        case arrivalTime = "arrival_time"
        case hobbsPhotoUrl = "hobbs_photo_url"
        case ocrConfidence = "ocr_confidence"
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case pilotUsername = "pilot_username"
        case pilotName = "pilot_name"
        case tailNumber = "tail_number"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        helicopterId = try container.decode(Int.self, forKey: .helicopterId)
        pilotId = try container.decodeIfPresent(Int.self, forKey: .pilotId)
        departureTime = try container.decodeIfPresent(String.self, forKey: .departureTime)
        arrivalTime = try container.decodeIfPresent(String.self, forKey: .arrivalTime)
        hobbsPhotoUrl = try container.decodeIfPresent(String.self, forKey: .hobbsPhotoUrl)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        pilotUsername = try container.decodeIfPresent(String.self, forKey: .pilotUsername)
        pilotName = try container.decodeIfPresent(String.self, forKey: .pilotName)
        tailNumber = try container.decodeIfPresent(String.self, forKey: .tailNumber)

        // Handle hobbsStart as either String or Double
        if let hobbsStartString = try? container.decodeIfPresent(String.self, forKey: .hobbsStart) {
            hobbsStart = Double(hobbsStartString)
        } else {
            hobbsStart = try container.decodeIfPresent(Double.self, forKey: .hobbsStart)
        }

        // Handle hobbsEnd as either String or Double
        if let hobbsEndString = try? container.decodeIfPresent(String.self, forKey: .hobbsEnd) {
            hobbsEnd = Double(hobbsEndString)
        } else {
            hobbsEnd = try container.decodeIfPresent(Double.self, forKey: .hobbsEnd)
        }

        // Handle flightTime as either String or Double
        if let flightTimeString = try? container.decodeIfPresent(String.self, forKey: .flightTime) {
            flightTime = Double(flightTimeString)
        } else {
            flightTime = try container.decodeIfPresent(Double.self, forKey: .flightTime)
        }

        // Handle tachTime as either String or Double
        if let tachTimeString = try? container.decodeIfPresent(String.self, forKey: .tachTime) {
            tachTime = Double(tachTimeString)
        } else {
            tachTime = try container.decodeIfPresent(Double.self, forKey: .tachTime)
        }

        // Handle ocrConfidence as either String or Double
        if let confidenceString = try? container.decodeIfPresent(String.self, forKey: .ocrConfidence) {
            ocrConfidence = Double(confidenceString)
        } else {
            ocrConfidence = try container.decodeIfPresent(Double.self, forKey: .ocrConfidence)
        }
    }

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Flight, rhs: Flight) -> Bool {
        lhs.id == rhs.id
    }
}

struct FlightCreate: Codable {
    let hobbsStart: Double?
    let hobbsEnd: Double?
    let flightTime: Double?
    let tachTime: Double?
    let departureTime: String?
    let arrivalTime: String?
    let hobbsPhotoUrl: String?
    let ocrConfidence: Double?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case hobbsStart = "hobbs_start"
        case hobbsEnd = "hobbs_end"
        case flightTime = "flight_time"
        case tachTime = "tach_time"
        case departureTime = "departure_time"
        case arrivalTime = "arrival_time"
        case hobbsPhotoUrl = "hobbs_photo_url"
        case ocrConfidence = "ocr_confidence"
        case notes
    }
}

// MARK: - Squawk Model

enum SquawkSeverity: String, Codable, CaseIterable {
    case routine = "routine"    // White
    case caution = "caution"    // Amber/Yellow
    case urgent = "urgent"      // Red

    var displayName: String {
        switch self {
        case .routine: return "Routine"
        case .caution: return "Caution"
        case .urgent: return "Urgent"
        }
    }
}

enum SquawkStatus: String, Codable, CaseIterable {
    case active = "active"
    case fixed = "fixed"
    case deferred = "deferred"

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .fixed: return "Fixed"
        case .deferred: return "Deferred"
        }
    }
}

struct Squawk: Codable, Identifiable, Hashable {
    let id: Int
    let helicopterId: Int
    let severity: SquawkSeverity
    let title: String
    let description: String?
    let reportedBy: Int?
    let reportedAt: String
    let status: SquawkStatus
    let photos: [String]?
    let fixedBy: Int?
    let fixedAt: String?
    let fixNotes: String?
    let createdAt: String?
    let updatedAt: String?

    // Additional fields from JOIN
    let reportedByUsername: String?
    let reportedByName: String?
    let fixedByUsername: String?
    let fixedByName: String?
    let tailNumber: String?

    enum CodingKeys: String, CodingKey {
        case id
        case helicopterId = "helicopter_id"
        case severity
        case title
        case description
        case reportedBy = "reported_by"
        case reportedAt = "reported_at"
        case status
        case photos
        case fixedBy = "fixed_by"
        case fixedAt = "fixed_at"
        case fixNotes = "fix_notes"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case reportedByUsername = "reported_by_username"
        case reportedByName = "reported_by_name"
        case fixedByUsername = "fixed_by_username"
        case fixedByName = "fixed_by_name"
        case tailNumber = "tail_number"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        helicopterId = try container.decode(Int.self, forKey: .helicopterId)

        // Decode severity
        let severityString = try container.decode(String.self, forKey: .severity)
        severity = SquawkSeverity(rawValue: severityString) ?? .routine

        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        reportedBy = try container.decodeIfPresent(Int.self, forKey: .reportedBy)
        reportedAt = try container.decode(String.self, forKey: .reportedAt)

        // Decode status
        let statusString = try container.decode(String.self, forKey: .status)
        status = SquawkStatus(rawValue: statusString) ?? .active

        // Decode photos array from JSONB
        if let photosArray = try? container.decodeIfPresent([String].self, forKey: .photos) {
            photos = photosArray
        } else {
            photos = nil
        }

        fixedBy = try container.decodeIfPresent(Int.self, forKey: .fixedBy)
        fixedAt = try container.decodeIfPresent(String.self, forKey: .fixedAt)
        fixNotes = try container.decodeIfPresent(String.self, forKey: .fixNotes)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        reportedByUsername = try container.decodeIfPresent(String.self, forKey: .reportedByUsername)
        reportedByName = try container.decodeIfPresent(String.self, forKey: .reportedByName)
        fixedByUsername = try container.decodeIfPresent(String.self, forKey: .fixedByUsername)
        fixedByName = try container.decodeIfPresent(String.self, forKey: .fixedByName)
        tailNumber = try container.decodeIfPresent(String.self, forKey: .tailNumber)
    }

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Squawk, rhs: Squawk) -> Bool {
        lhs.id == rhs.id
    }
}

struct SquawkCreate: Codable {
    let severity: String
    let title: String
    let description: String?
    let photos: [String]?
}

struct SquawkUpdate: Codable {
    let severity: String
    let title: String
    let description: String?
    let photos: [String]?
}

struct SquawkFixRequest: Codable {
    let fixNotes: String?

    enum CodingKeys: String, CodingKey {
        case fixNotes = "fix_notes"
    }
}

struct SquawkStatusUpdate: Codable {
    let status: String
}
