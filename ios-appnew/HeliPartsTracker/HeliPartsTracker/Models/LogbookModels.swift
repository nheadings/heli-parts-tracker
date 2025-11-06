import Foundation

// MARK: - Helicopter Hours

struct HelicopterHours: Codable, Identifiable {
    let id: Int
    let helicopterId: Int
    let hours: Double
    let recordedAt: String
    let recordedBy: Int?
    let recordedByUsername: String?
    let photoUrl: String?
    let ocrConfidence: Double?
    let entryMethod: String // manual, ocr, automatic
    let notes: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case helicopterId = "helicopter_id"
        case hours
        case recordedAt = "recorded_at"
        case recordedBy = "recorded_by"
        case recordedByUsername = "recorded_by_username"
        case photoUrl = "photo_url"
        case ocrConfidence = "ocr_confidence"
        case entryMethod = "entry_method"
        case notes
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        helicopterId = try container.decode(Int.self, forKey: .helicopterId)
        recordedAt = try container.decode(String.self, forKey: .recordedAt)
        recordedBy = try container.decodeIfPresent(Int.self, forKey: .recordedBy)
        recordedByUsername = try container.decodeIfPresent(String.self, forKey: .recordedByUsername)
        photoUrl = try container.decodeIfPresent(String.self, forKey: .photoUrl)
        entryMethod = try container.decode(String.self, forKey: .entryMethod)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)

        // Handle hours as either String or Double (PostgreSQL DECIMAL returns as String)
        if let hoursString = try? container.decodeIfPresent(String.self, forKey: .hours) {
            hours = Double(hoursString) ?? 0.0
        } else {
            hours = try container.decode(Double.self, forKey: .hours)
        }

        // Handle ocrConfidence as either String or Double
        if let confidenceString = try? container.decodeIfPresent(String.self, forKey: .ocrConfidence) {
            ocrConfidence = Double(confidenceString)
        } else {
            ocrConfidence = try container.decodeIfPresent(Double.self, forKey: .ocrConfidence)
        }
    }
}

struct HelicopterHoursCreate: Codable {
    let hours: Double
    let photoUrl: String?
    let ocrConfidence: Double?
    let entryMethod: String
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case hours
        case photoUrl = "photo_url"
        case ocrConfidence = "ocr_confidence"
        case entryMethod = "entry_method"
        case notes
    }
}

struct HelicopterHoursResponse: Codable {
    let currentHours: Double
    let history: [HelicopterHours]

    enum CodingKeys: String, CodingKey {
        case currentHours = "current_hours"
        case history
    }
}

// MARK: - Maintenance Logs

struct MaintenanceLog: Codable, Identifiable, Hashable {
    let id: Int
    let helicopterId: Int
    let logType: String // oil_change, inspection, repair, ad_compliance, service
    let hoursAtService: Double?
    let datePerformed: String
    let performedBy: Int?
    let performedByUsername: String?
    let description: String
    let cost: Double?
    let nextDueHours: Double?
    let nextDueDate: String?
    let attachments: [String]?
    let status: String // scheduled, in_progress, completed
    let createdAt: String?
    let updatedAt: String?

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: MaintenanceLog, rhs: MaintenanceLog) -> Bool {
        lhs.id == rhs.id
    }

    enum CodingKeys: String, CodingKey {
        case id
        case helicopterId = "helicopter_id"
        case logType = "log_type"
        case hoursAtService = "hours_at_service"
        case datePerformed = "date_performed"
        case performedBy = "performed_by"
        case performedByUsername = "performed_by_username"
        case description, cost
        case nextDueHours = "next_due_hours"
        case nextDueDate = "next_due_date"
        case attachments, status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var displayLogType: String {
        switch logType {
        case "oil_change": return "Oil Change"
        case "inspection": return "Inspection"
        case "repair": return "Repair"
        case "ad_compliance": return "AD Compliance"
        case "service": return "Service"
        default: return logType.capitalized
        }
    }

    var isOverdue: Bool {
        guard let nextDue = nextDueHours else { return false }
        // This would need current hours to calculate properly
        return false // Will implement in view model
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        helicopterId = try container.decode(Int.self, forKey: .helicopterId)
        logType = try container.decode(String.self, forKey: .logType)
        datePerformed = try container.decode(String.self, forKey: .datePerformed)
        performedBy = try container.decodeIfPresent(Int.self, forKey: .performedBy)
        performedByUsername = try container.decodeIfPresent(String.self, forKey: .performedByUsername)
        description = try container.decode(String.self, forKey: .description)
        nextDueDate = try container.decodeIfPresent(String.self, forKey: .nextDueDate)
        attachments = try container.decodeIfPresent([String].self, forKey: .attachments)
        status = try container.decode(String.self, forKey: .status)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)

        // Handle hoursAtService as either String or Double
        if let hoursString = try? container.decodeIfPresent(String.self, forKey: .hoursAtService) {
            hoursAtService = Double(hoursString)
        } else {
            hoursAtService = try container.decodeIfPresent(Double.self, forKey: .hoursAtService)
        }

        // Handle cost as either String or Double
        if let costString = try? container.decodeIfPresent(String.self, forKey: .cost) {
            cost = Double(costString)
        } else {
            cost = try container.decodeIfPresent(Double.self, forKey: .cost)
        }

        // Handle nextDueHours as either String or Double
        if let nextDueString = try? container.decodeIfPresent(String.self, forKey: .nextDueHours) {
            nextDueHours = Double(nextDueString)
        } else {
            nextDueHours = try container.decodeIfPresent(Double.self, forKey: .nextDueHours)
        }
    }
}

struct MaintenanceLogCreate: Codable {
    let logType: String
    let hoursAtService: Double?
    let datePerformed: String
    let description: String
    let cost: Double?
    let nextDueHours: Double?
    let nextDueDate: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case logType = "log_type"
        case hoursAtService = "hours_at_service"
        case datePerformed = "date_performed"
        case description, cost
        case nextDueHours = "next_due_hours"
        case nextDueDate = "next_due_date"
        case status
    }
}

// MARK: - Fluid Logs

struct FluidLog: Codable, Identifiable, Hashable {
    let id: Int
    let helicopterId: Int
    let fluidType: String // engine_oil, transmission_oil, hydraulic_fluid, fuel
    let quantity: Double
    let unit: String // quarts, liters, gallons
    let hours: Double?
    let dateAdded: String
    let addedBy: Int?
    let addedByUsername: String?
    let notes: String?
    let createdAt: String?

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FluidLog, rhs: FluidLog) -> Bool {
        lhs.id == rhs.id
    }

    enum CodingKeys: String, CodingKey {
        case id
        case helicopterId = "helicopter_id"
        case fluidType = "fluid_type"
        case quantity, unit, hours
        case dateAdded = "date_added"
        case addedBy = "added_by"
        case addedByUsername = "added_by_username"
        case notes
        case createdAt = "created_at"
    }

    var displayFluidType: String {
        switch fluidType {
        case "engine_oil": return "Engine Oil"
        case "transmission_oil": return "Transmission Oil"
        case "hydraulic_fluid": return "Hydraulic Fluid"
        case "fuel": return "Fuel"
        default: return fluidType.capitalized
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        helicopterId = try container.decode(Int.self, forKey: .helicopterId)
        fluidType = try container.decode(String.self, forKey: .fluidType)
        unit = try container.decode(String.self, forKey: .unit)
        dateAdded = try container.decode(String.self, forKey: .dateAdded)
        addedBy = try container.decodeIfPresent(Int.self, forKey: .addedBy)
        addedByUsername = try container.decodeIfPresent(String.self, forKey: .addedByUsername)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)

        // Handle quantity as either String or Double
        if let qtyString = try? container.decodeIfPresent(String.self, forKey: .quantity) {
            quantity = Double(qtyString) ?? 0.0
        } else {
            quantity = try container.decode(Double.self, forKey: .quantity)
        }

        // Handle hours as either String or Double
        if let hoursString = try? container.decodeIfPresent(String.self, forKey: .hours) {
            hours = Double(hoursString)
        } else {
            hours = try container.decodeIfPresent(Double.self, forKey: .hours)
        }
    }
}

struct FluidLogCreate: Codable {
    let fluidType: String
    let quantity: Double
    let unit: String
    let hours: Double?
    let dateAdded: String
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case fluidType = "fluid_type"
        case quantity, unit, hours
        case dateAdded = "date_added"
        case notes
    }
}

// MARK: - Life Limited Parts

struct LifeLimitedPart: Codable, Identifiable {
    let id: Int
    let partId: Int?
    let installationId: Int?
    let helicopterId: Int
    let partSerialNumber: String?
    let hourLimit: Double?
    let calendarLimitMonths: Int?
    let installedHours: Double
    let installedDate: String
    let status: String // active, expired, removed
    let alertThresholdPercent: Int
    let notes: String?
    let partNumber: String?
    let partDescription: String?
    let hoursRemaining: Double?
    let daysRemaining: Int?
    let percentRemaining: Double?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case partId = "part_id"
        case installationId = "installation_id"
        case helicopterId = "helicopter_id"
        case partSerialNumber = "part_serial_number"
        case hourLimit = "hour_limit"
        case calendarLimitMonths = "calendar_limit_months"
        case installedHours = "installed_hours"
        case installedDate = "installed_date"
        case status
        case alertThresholdPercent = "alert_threshold_percent"
        case notes
        case partNumber = "part_number"
        case partDescription = "part_description"
        case hoursRemaining = "hours_remaining"
        case daysRemaining = "days_remaining"
        case percentRemaining = "percent_remaining"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var isExpired: Bool {
        status == "expired"
    }

    var isNearExpiration: Bool {
        guard let percent = percentRemaining else { return false }
        return percent <= Double(alertThresholdPercent)
    }

    var displayStatus: String {
        if isExpired {
            return "Expired"
        } else if isNearExpiration {
            return "Due Soon"
        } else {
            return "Active"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        partId = try container.decodeIfPresent(Int.self, forKey: .partId)
        installationId = try container.decodeIfPresent(Int.self, forKey: .installationId)
        helicopterId = try container.decode(Int.self, forKey: .helicopterId)
        partSerialNumber = try container.decodeIfPresent(String.self, forKey: .partSerialNumber)
        calendarLimitMonths = try container.decodeIfPresent(Int.self, forKey: .calendarLimitMonths)
        installedDate = try container.decode(String.self, forKey: .installedDate)
        status = try container.decode(String.self, forKey: .status)
        alertThresholdPercent = try container.decode(Int.self, forKey: .alertThresholdPercent)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        partNumber = try container.decodeIfPresent(String.self, forKey: .partNumber)
        partDescription = try container.decodeIfPresent(String.self, forKey: .partDescription)
        daysRemaining = try container.decodeIfPresent(Int.self, forKey: .daysRemaining)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)

        // Handle hourLimit as either String or Double
        if let limitString = try? container.decodeIfPresent(String.self, forKey: .hourLimit) {
            hourLimit = Double(limitString)
        } else {
            hourLimit = try container.decodeIfPresent(Double.self, forKey: .hourLimit)
        }

        // Handle installedHours as either String or Double
        if let hoursString = try? container.decodeIfPresent(String.self, forKey: .installedHours) {
            installedHours = Double(hoursString) ?? 0.0
        } else {
            installedHours = try container.decode(Double.self, forKey: .installedHours)
        }

        // Handle hoursRemaining as either String or Double
        if let remainingString = try? container.decodeIfPresent(String.self, forKey: .hoursRemaining) {
            hoursRemaining = Double(remainingString)
        } else {
            hoursRemaining = try container.decodeIfPresent(Double.self, forKey: .hoursRemaining)
        }

        // Handle percentRemaining as either String or Double
        if let percentString = try? container.decodeIfPresent(String.self, forKey: .percentRemaining) {
            percentRemaining = Double(percentString)
        } else {
            percentRemaining = try container.decodeIfPresent(Double.self, forKey: .percentRemaining)
        }
    }
}

struct LifeLimitedPartCreate: Codable {
    let partId: Int?
    let installationId: Int?
    let helicopterId: Int
    let partSerialNumber: String?
    let hourLimit: Double?
    let calendarLimitMonths: Int?
    let installedHours: Double
    let installedDate: String
    let alertThresholdPercent: Int?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case partId = "part_id"
        case installationId = "installation_id"
        case helicopterId = "helicopter_id"
        case partSerialNumber = "part_serial_number"
        case hourLimit = "hour_limit"
        case calendarLimitMonths = "calendar_limit_months"
        case installedHours = "installed_hours"
        case installedDate = "installed_date"
        case alertThresholdPercent = "alert_threshold_percent"
        case notes
    }
}

// MARK: - Maintenance Schedules

struct MaintenanceSchedule: Codable, Identifiable {
    let id: Int
    let title: String
    let description: String?
    let intervalHours: Double?
    let intervalDays: Int?
    let isTemplate: Bool
    let helicopterId: Int?
    let category: String? // ad, inspection, service, overhaul
    let createdBy: Int?
    let isActive: Bool
    let lastCompletedHours: Double?
    let lastCompletedDate: String?
    let nextDueHours: Double?
    let nextDueDate: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description
        case intervalHours = "interval_hours"
        case intervalDays = "interval_days"
        case isTemplate = "is_template"
        case helicopterId = "helicopter_id"
        case category
        case createdBy = "created_by"
        case isActive = "is_active"
        case lastCompletedHours = "last_completed_hours"
        case lastCompletedDate = "last_completed_date"
        case nextDueHours = "next_due_hours"
        case nextDueDate = "next_due_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var intervalDescription: String {
        var parts: [String] = []
        if let hours = intervalHours {
            parts.append("\(Int(hours)) hours")
        }
        if let days = intervalDays {
            parts.append("\(days) days")
        }
        return parts.joined(separator: " or ")
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        intervalDays = try container.decodeIfPresent(Int.self, forKey: .intervalDays)
        isTemplate = try container.decode(Bool.self, forKey: .isTemplate)
        helicopterId = try container.decodeIfPresent(Int.self, forKey: .helicopterId)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        createdBy = try container.decodeIfPresent(Int.self, forKey: .createdBy)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        lastCompletedDate = try container.decodeIfPresent(String.self, forKey: .lastCompletedDate)
        nextDueDate = try container.decodeIfPresent(String.self, forKey: .nextDueDate)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)

        // Handle intervalHours as either String or Double
        if let hoursString = try? container.decodeIfPresent(String.self, forKey: .intervalHours) {
            intervalHours = Double(hoursString)
        } else {
            intervalHours = try container.decodeIfPresent(Double.self, forKey: .intervalHours)
        }

        // Handle lastCompletedHours as either String or Double
        if let completedString = try? container.decodeIfPresent(String.self, forKey: .lastCompletedHours) {
            lastCompletedHours = Double(completedString)
        } else {
            lastCompletedHours = try container.decodeIfPresent(Double.self, forKey: .lastCompletedHours)
        }

        // Handle nextDueHours as either String or Double
        if let dueString = try? container.decodeIfPresent(String.self, forKey: .nextDueHours) {
            nextDueHours = Double(dueString)
        } else {
            nextDueHours = try container.decodeIfPresent(Double.self, forKey: .nextDueHours)
        }
    }
}

struct MaintenanceScheduleCreate: Codable {
    let title: String
    let description: String?
    let intervalHours: Double?
    let intervalDays: Int?
    let helicopterId: Int?
    let category: String?

    enum CodingKeys: String, CodingKey {
        case title, description
        case intervalHours = "interval_hours"
        case intervalDays = "interval_days"
        case helicopterId = "helicopter_id"
        case category
    }
}

// MARK: - Dashboard

struct LogbookDashboard: Codable {
    let helicopter: HelicopterDetail
    let oilChange: MaintenanceLog?
    let hoursUntilOilChange: Double?
    let upcomingMaintenance: [UpcomingMaintenance]
    let lifeLimitedParts: [LifeLimitedPart]
    let recentFluids: [FluidLog]
    let recentInstallations: [PartInstallation]

    enum CodingKeys: String, CodingKey {
        case helicopter
        case oilChange = "oil_change"
        case hoursUntilOilChange = "hours_until_oil_change"
        case upcomingMaintenance = "upcoming_maintenance"
        case lifeLimitedParts = "life_limited_parts"
        case recentFluids = "recent_fluids"
        case recentInstallations = "recent_installations"
    }

    init(helicopter: HelicopterDetail, oilChange: MaintenanceLog?, hoursUntilOilChange: Double?, upcomingMaintenance: [UpcomingMaintenance], lifeLimitedParts: [LifeLimitedPart], recentFluids: [FluidLog], recentInstallations: [PartInstallation]) {
        self.helicopter = helicopter
        self.oilChange = oilChange
        self.hoursUntilOilChange = hoursUntilOilChange
        self.upcomingMaintenance = upcomingMaintenance
        self.lifeLimitedParts = lifeLimitedParts
        self.recentFluids = recentFluids
        self.recentInstallations = recentInstallations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        helicopter = try container.decode(HelicopterDetail.self, forKey: .helicopter)
        oilChange = try container.decodeIfPresent(MaintenanceLog.self, forKey: .oilChange)
        upcomingMaintenance = try container.decode([UpcomingMaintenance].self, forKey: .upcomingMaintenance)
        lifeLimitedParts = try container.decode([LifeLimitedPart].self, forKey: .lifeLimitedParts)
        recentFluids = try container.decode([FluidLog].self, forKey: .recentFluids)
        recentInstallations = try container.decode([PartInstallation].self, forKey: .recentInstallations)

        // Handle hoursUntilOilChange as either String or Double
        if let hoursString = try? container.decodeIfPresent(String.self, forKey: .hoursUntilOilChange) {
            hoursUntilOilChange = Double(hoursString)
        } else {
            hoursUntilOilChange = try container.decodeIfPresent(Double.self, forKey: .hoursUntilOilChange)
        }
    }
}

struct HelicopterDetail: Codable {
    let id: Int
    let tailNumber: String
    let model: String
    let manufacturer: String?
    let serialNumber: String?
    let currentHours: Double
    let status: String?

    enum CodingKeys: String, CodingKey {
        case id
        case tailNumber = "tail_number"
        case model, manufacturer
        case serialNumber = "serial_number"
        case currentHours = "current_hours"
        case status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        tailNumber = try container.decode(String.self, forKey: .tailNumber)
        model = try container.decode(String.self, forKey: .model)
        manufacturer = try container.decodeIfPresent(String.self, forKey: .manufacturer)
        serialNumber = try container.decodeIfPresent(String.self, forKey: .serialNumber)
        status = try container.decodeIfPresent(String.self, forKey: .status)

        // Handle current_hours as either String or Double
        if let hoursString = try? container.decodeIfPresent(String.self, forKey: .currentHours) {
            currentHours = Double(hoursString) ?? 0.0
        } else {
            currentHours = try container.decodeIfPresent(Double.self, forKey: .currentHours) ?? 0.0
        }
    }
}

struct UpcomingMaintenance: Codable, Identifiable {
    let id: Int
    let title: String
    let category: String?
    let nextDueHours: Double?
    let nextDueDate: String?
    let hoursRemaining: Double?
    let daysRemaining: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, category
        case nextDueHours = "next_due_hours"
        case nextDueDate = "next_due_date"
        case hoursRemaining = "hours_remaining"
        case daysRemaining = "days_remaining"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        nextDueDate = try container.decodeIfPresent(String.self, forKey: .nextDueDate)
        daysRemaining = try container.decodeIfPresent(Int.self, forKey: .daysRemaining)

        // Handle nextDueHours as either String or Double
        if let dueString = try? container.decodeIfPresent(String.self, forKey: .nextDueHours) {
            nextDueHours = Double(dueString)
        } else {
            nextDueHours = try container.decodeIfPresent(Double.self, forKey: .nextDueHours)
        }

        // Handle hoursRemaining as either String or Double
        if let remainingString = try? container.decodeIfPresent(String.self, forKey: .hoursRemaining) {
            hoursRemaining = Double(remainingString)
        } else {
            hoursRemaining = try container.decodeIfPresent(Double.self, forKey: .hoursRemaining)
        }
    }
}
