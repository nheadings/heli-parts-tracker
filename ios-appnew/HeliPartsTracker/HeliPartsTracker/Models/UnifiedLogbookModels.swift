import Foundation

// MARK: - Logbook Category

struct LogbookCategory: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let icon: String
    let color: String
    let displayOrder: Int
    let isActive: Bool
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case icon
        case color
        case displayOrder = "display_order"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
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

    // Joined fields
    let categoryName: String
    let categoryIcon: String
    let categoryColor: String
    let tailNumber: String
    let performedByUsername: String?
    let performedByName: String?

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
        case categoryName = "category_name"
        case categoryIcon = "category_icon"
        case categoryColor = "category_color"
        case tailNumber = "tail_number"
        case performedByUsername = "performed_by_username"
        case performedByName = "performed_by_name"
        case attachments
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
