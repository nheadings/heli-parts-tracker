import Foundation

struct Part: Codable, Identifiable, Hashable {
    let id: Int
    let partNumber: String
    let alternatePartNumber: String?
    let description: String
    let manufacturer: String?
    let category: String?
    let quantityInStock: Int
    let minimumQuantity: Int?
    let unitPrice: Double?
    let reorderUrl: String?
    let location: String?
    let qrCode: String?
    let notes: String?
    let createdAt: String?
    let updatedAt: String?
    let isLifeLimited: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case partNumber = "part_number"
        case alternatePartNumber = "alternate_part_number"
        case description, manufacturer, category
        case quantityInStock = "quantity_in_stock"
        case minimumQuantity = "minimum_quantity"
        case unitPrice = "unit_price"
        case reorderUrl = "reorder_url"
        case location, notes
        case qrCode = "qr_code"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isLifeLimited = "is_life_limited"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        partNumber = try container.decode(String.self, forKey: .partNumber)
        alternatePartNumber = try container.decodeIfPresent(String.self, forKey: .alternatePartNumber)
        description = try container.decode(String.self, forKey: .description)
        manufacturer = try container.decodeIfPresent(String.self, forKey: .manufacturer)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        quantityInStock = try container.decode(Int.self, forKey: .quantityInStock)
        minimumQuantity = try container.decodeIfPresent(Int.self, forKey: .minimumQuantity)

        // Handle unit_price as either String or Double
        if let priceString = try? container.decodeIfPresent(String.self, forKey: .unitPrice) {
            unitPrice = Double(priceString)
        } else {
            unitPrice = try container.decodeIfPresent(Double.self, forKey: .unitPrice)
        }

        reorderUrl = try container.decodeIfPresent(String.self, forKey: .reorderUrl)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        qrCode = try container.decodeIfPresent(String.self, forKey: .qrCode)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        isLifeLimited = try container.decodeIfPresent(Bool.self, forKey: .isLifeLimited)
    }

    var isLowStock: Bool {
        guard let minQty = minimumQuantity else { return false }
        return quantityInStock <= minQty
    }
}

struct PartCreate: Codable {
    let partNumber: String
    let alternatePartNumber: String?
    let description: String
    let manufacturer: String?
    let category: String?
    let quantityInStock: Int
    let minimumQuantity: Int?
    let unitPrice: Double?
    let reorderUrl: String?
    let location: String?
    let isLifeLimited: Bool

    enum CodingKeys: String, CodingKey {
        case partNumber = "part_number"
        case alternatePartNumber = "alternate_part_number"
        case description, manufacturer, category
        case quantityInStock = "quantity_in_stock"
        case minimumQuantity = "minimum_quantity"
        case unitPrice = "unit_price"
        case reorderUrl = "reorder_url"
        case location
        case isLifeLimited = "is_life_limited"
    }
}
