import Foundation

// MARK: - Logbook Category

struct LogbookCategory: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let icon: String
    let color: String
    let displayOrder: Int
    let isActive: Bool
    let displayInFlightView: Bool?
    let intervalHours: Double?
    let thresholdWarning: Int?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case icon
        case color
        case displayOrder = "display_order"
        case isActive = "is_active"
        case displayInFlightView = "display_in_flight_view"
        case intervalHours = "interval_hours"
        case thresholdWarning = "threshold_warning"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decode(String.self, forKey: .icon)
        color = try container.decode(String.self, forKey: .color)
        displayOrder = try container.decode(Int.self, forKey: .displayOrder)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        displayInFlightView = try? container.decodeIfPresent(Bool.self, forKey: .displayInFlightView)
        thresholdWarning = try? container.decodeIfPresent(Int.self, forKey: .thresholdWarning)
        createdAt = try? container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try? container.decodeIfPresent(String.self, forKey: .updatedAt)

        // Handle intervalHours as string or double
        if let hoursString = try? container.decodeIfPresent(String.self, forKey: .intervalHours) {
            intervalHours = Double(hoursString)
        } else {
            intervalHours = try? container.decodeIfPresent(Double.self, forKey: .intervalHours)
        }
    }
}

struct LogbookCategoryCreate: Codable {
    let name: String
    let icon: String
    let color: String
    let displayOrder: Int

    enum CodingKeys: String, CodingKey {
        case name
        case icon
        case color
        case displayOrder = "display_order"
    }
}

// MARK: - Logbook Entry

struct LogbookEntry: Codable, Identifiable {
    let id: Int
    let helicopterId: Int
    let categoryId: Int
    let eventDate: String
    let hoursAtEvent: Double?
    let description: String
    let notes: String?
    let performedBy: Int?
    let cost: Double?
    let nextDueHours: Double?
    let nextDueDate: String?

    // Specialized fields
    let severity: String?
    let status: String?
    let fluidType: String?
    let quantity: Double?
    let unit: String?
    let fixedBy: Int?
    let fixedAt: String?
    let fixNotes: String?

    // Reference IDs
    let flightId: Int?
    let maintenanceLogId: Int?
    let maintenanceCompletionId: Int?
    let fluidLogId: Int?
    let partInstallationId: Int?
    let squawkId: Int?

    // Joined fields
    let categoryName: String
    let categoryIcon: String
    let categoryColor: String
    let tailNumber: String
    let performedByUsername: String?
    let performedByName: String?
    let attachmentCount: Int?

    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case helicopterId = "helicopter_id"
        case categoryId = "category_id"
        case eventDate = "event_date"
        case hoursAtEvent = "hours_at_event"
        case description
        case notes
        case performedBy = "performed_by"
        case cost
        case nextDueHours = "next_due_hours"
        case nextDueDate = "next_due_date"
        case severity
        case status
        case fluidType = "fluid_type"
        case quantity
        case unit
        case fixedBy = "fixed_by"
        case fixedAt = "fixed_at"
        case fixNotes = "fix_notes"
        case flightId = "flight_id"
        case maintenanceLogId = "maintenance_log_id"
        case maintenanceCompletionId = "maintenance_completion_id"
        case fluidLogId = "fluid_log_id"
        case partInstallationId = "part_installation_id"
        case squawkId = "squawk_id"
        case categoryName = "category_name"
        case categoryIcon = "category_icon"
        case categoryColor = "category_color"
        case tailNumber = "tail_number"
        case performedByUsername = "performed_by_username"
        case performedByName = "performed_by_name"
        case attachmentCount = "attachment_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(Int.self, forKey: .id)
        helicopterId = try container.decode(Int.self, forKey: .helicopterId)
        categoryId = try container.decode(Int.self, forKey: .categoryId)
        eventDate = try container.decode(String.self, forKey: .eventDate)
        description = try container.decode(String.self, forKey: .description)
        notes = try? container.decodeIfPresent(String.self, forKey: .notes)
        performedBy = try? container.decodeIfPresent(Int.self, forKey: .performedBy)
        nextDueDate = try? container.decodeIfPresent(String.self, forKey: .nextDueDate)
        flightId = try? container.decodeIfPresent(Int.self, forKey: .flightId)
        maintenanceLogId = try? container.decodeIfPresent(Int.self, forKey: .maintenanceLogId)
        maintenanceCompletionId = try? container.decodeIfPresent(Int.self, forKey: .maintenanceCompletionId)
        fluidLogId = try? container.decodeIfPresent(Int.self, forKey: .fluidLogId)
        partInstallationId = try? container.decodeIfPresent(Int.self, forKey: .partInstallationId)
        squawkId = try? container.decodeIfPresent(Int.self, forKey: .squawkId)
        categoryName = try container.decode(String.self, forKey: .categoryName)
        categoryIcon = try container.decode(String.self, forKey: .categoryIcon)
        categoryColor = try container.decode(String.self, forKey: .categoryColor)
        tailNumber = try container.decode(String.self, forKey: .tailNumber)
        performedByUsername = try? container.decodeIfPresent(String.self, forKey: .performedByUsername)
        performedByName = try? container.decodeIfPresent(String.self, forKey: .performedByName)
        attachmentCount = try? container.decodeIfPresent(Int.self, forKey: .attachmentCount)
        createdAt = try? container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try? container.decodeIfPresent(String.self, forKey: .updatedAt)

        // Specialized fields
        severity = try? container.decodeIfPresent(String.self, forKey: .severity)
        status = try? container.decodeIfPresent(String.self, forKey: .status)
        fluidType = try? container.decodeIfPresent(String.self, forKey: .fluidType)
        unit = try? container.decodeIfPresent(String.self, forKey: .unit)
        fixedBy = try? container.decodeIfPresent(Int.self, forKey: .fixedBy)
        fixedAt = try? container.decodeIfPresent(String.self, forKey: .fixedAt)
        fixNotes = try? container.decodeIfPresent(String.self, forKey: .fixNotes)

        // Handle numeric fields that may come as strings from PostgreSQL
        if let hoursString = try? container.decodeIfPresent(String.self, forKey: .hoursAtEvent) {
            hoursAtEvent = Double(hoursString)
        } else {
            hoursAtEvent = try? container.decodeIfPresent(Double.self, forKey: .hoursAtEvent)
        }

        if let costString = try? container.decodeIfPresent(String.self, forKey: .cost) {
            cost = Double(costString)
        } else {
            cost = try? container.decodeIfPresent(Double.self, forKey: .cost)
        }

        if let nextHoursString = try? container.decodeIfPresent(String.self, forKey: .nextDueHours) {
            nextDueHours = Double(nextHoursString)
        } else {
            nextDueHours = try? container.decodeIfPresent(Double.self, forKey: .nextDueHours)
        }

        if let qtyString = try? container.decodeIfPresent(String.self, forKey: .quantity) {
            quantity = Double(qtyString)
        } else {
            quantity = try? container.decodeIfPresent(Double.self, forKey: .quantity)
        }
    }
}

struct LogbookEntryDetail: Codable, Identifiable {
    let id: Int
    let helicopterId: Int
    let categoryId: Int
    let eventDate: String
    let hoursAtEvent: Double?
    let description: String
    let notes: String?
    let performedBy: Int?
    let cost: Double?
    let nextDueHours: Double?
    let nextDueDate: String?

    // Specialized fields
    let severity: String?
    let status: String?
    let fluidType: String?
    let quantity: Double?
    let unit: String?
    let fixedBy: Int?
    let fixedAt: String?
    let fixNotes: String?

    // Joined fields
    let categoryName: String
    let categoryIcon: String
    let categoryColor: String
    let tailNumber: String
    let performedByUsername: String?
    let performedByName: String?
    let fixedByUsername: String?
    let fixedByName: String?

    // Attachments
    let attachments: [LogbookAttachment]

    enum CodingKeys: String, CodingKey {
        case id
        case helicopterId = "helicopter_id"
        case categoryId = "category_id"
        case eventDate = "event_date"
        case hoursAtEvent = "hours_at_event"
        case description
        case notes
        case performedBy = "performed_by"
        case cost
        case nextDueHours = "next_due_hours"
        case nextDueDate = "next_due_date"
        case severity, status
        case fluidType = "fluid_type"
        case quantity, unit
        case fixedBy = "fixed_by"
        case fixedAt = "fixed_at"
        case fixNotes = "fix_notes"
        case categoryName = "category_name"
        case categoryIcon = "category_icon"
        case categoryColor = "category_color"
        case tailNumber = "tail_number"
        case performedByUsername = "performed_by_username"
        case performedByName = "performed_by_name"
        case fixedByUsername = "fixed_by_username"
        case fixedByName = "fixed_by_name"
        case attachments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(Int.self, forKey: .id)
        helicopterId = try container.decode(Int.self, forKey: .helicopterId)
        categoryId = try container.decode(Int.self, forKey: .categoryId)
        eventDate = try container.decode(String.self, forKey: .eventDate)
        description = try container.decode(String.self, forKey: .description)
        notes = try? container.decodeIfPresent(String.self, forKey: .notes)
        performedBy = try? container.decodeIfPresent(Int.self, forKey: .performedBy)
        nextDueDate = try? container.decodeIfPresent(String.self, forKey: .nextDueDate)
        categoryName = try container.decode(String.self, forKey: .categoryName)
        categoryIcon = try container.decode(String.self, forKey: .categoryIcon)
        categoryColor = try container.decode(String.self, forKey: .categoryColor)
        tailNumber = try container.decode(String.self, forKey: .tailNumber)
        performedByUsername = try? container.decodeIfPresent(String.self, forKey: .performedByUsername)
        performedByName = try? container.decodeIfPresent(String.self, forKey: .performedByName)
        fixedByUsername = try? container.decodeIfPresent(String.self, forKey: .fixedByUsername)
        fixedByName = try? container.decodeIfPresent(String.self, forKey: .fixedByName)
        attachments = try container.decode([LogbookAttachment].self, forKey: .attachments)

        // Specialized fields
        severity = try? container.decodeIfPresent(String.self, forKey: .severity)
        status = try? container.decodeIfPresent(String.self, forKey: .status)
        fluidType = try? container.decodeIfPresent(String.self, forKey: .fluidType)
        unit = try? container.decodeIfPresent(String.self, forKey: .unit)
        fixedBy = try? container.decodeIfPresent(Int.self, forKey: .fixedBy)
        fixedAt = try? container.decodeIfPresent(String.self, forKey: .fixedAt)
        fixNotes = try? container.decodeIfPresent(String.self, forKey: .fixNotes)

        // Handle numeric fields that may come as strings from PostgreSQL
        if let hoursString = try? container.decodeIfPresent(String.self, forKey: .hoursAtEvent) {
            hoursAtEvent = Double(hoursString)
        } else {
            hoursAtEvent = try? container.decodeIfPresent(Double.self, forKey: .hoursAtEvent)
        }

        if let costString = try? container.decodeIfPresent(String.self, forKey: .cost) {
            cost = Double(costString)
        } else {
            cost = try? container.decodeIfPresent(Double.self, forKey: .cost)
        }

        if let nextHoursString = try? container.decodeIfPresent(String.self, forKey: .nextDueHours) {
            nextDueHours = Double(nextHoursString)
        } else {
            nextDueHours = try? container.decodeIfPresent(Double.self, forKey: .nextDueHours)
        }

        if let qtyString = try? container.decodeIfPresent(String.self, forKey: .quantity) {
            quantity = Double(qtyString)
        } else {
            quantity = try? container.decodeIfPresent(Double.self, forKey: .quantity)
        }
    }
}

struct LogbookEntryCreate: Codable {
    let helicopterId: Int
    let categoryId: Int
    let eventDate: String?
    let hoursAtEvent: Double?
    let description: String
    let notes: String?
    let cost: Double?
    let nextDueHours: Double?
    let nextDueDate: String?

    // Specialized fields
    let severity: String?
    let status: String?
    let fluidType: String?
    let quantity: Double?
    let unit: String?
    let fixedBy: Int?
    let fixedAt: String?
    let fixNotes: String?

    enum CodingKeys: String, CodingKey {
        case helicopterId = "helicopter_id"
        case categoryId = "category_id"
        case eventDate = "event_date"
        case hoursAtEvent = "hours_at_event"
        case description
        case notes
        case cost
        case nextDueHours = "next_due_hours"
        case nextDueDate = "next_due_date"
        case severity, status
        case fluidType = "fluid_type"
        case quantity, unit
        case fixedBy = "fixed_by"
        case fixedAt = "fixed_at"
        case fixNotes = "fix_notes"
    }
}

// MARK: - Logbook Attachment

struct LogbookAttachment: Codable, Identifiable {
    let id: Int
    let entryId: Int
    let fileName: String
    let filePath: String
    let fileType: String?
    let fileSize: Int?
    let uploadedBy: Int?
    let uploadedByUsername: String?
    let uploadedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case entryId = "entry_id"
        case fileName = "file_name"
        case filePath = "file_path"
        case fileType = "file_type"
        case fileSize = "file_size"
        case uploadedBy = "uploaded_by"
        case uploadedByUsername = "uploaded_by_username"
        case uploadedAt = "uploaded_at"
    }
}
