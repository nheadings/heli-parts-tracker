import Foundation

struct InventoryTransaction: Codable, Identifiable {
    let id: Int
    let partId: Int
    let transactionType: String
    let quantityChange: Int
    let quantityAfter: Int
    let transactionDate: String
    let performedBy: Int?
    let performedByUsername: String?
    let performedByFullName: String?
    let referenceType: String?
    let referenceId: Int?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case partId = "part_id"
        case transactionType = "transaction_type"
        case quantityChange = "quantity_change"
        case quantityAfter = "quantity_after"
        case transactionDate = "transaction_date"
        case performedBy = "performed_by"
        case performedByUsername = "performed_by_username"
        case performedByFullName = "performed_by_full_name"
        case referenceType = "reference_type"
        case referenceId = "reference_id"
        case notes
    }
}
