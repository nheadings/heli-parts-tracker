import Foundation

struct User: Codable, Identifiable {
    let id: Int
    let username: String
    let email: String?
    let fullName: String?
    let role: String

    enum CodingKeys: String, CodingKey {
        case id, username, email, role
        case fullName = "full_name"
    }
}

struct LoginResponse: Codable {
    let token: String
    let user: User
}

// MARK: - Manual URLs

struct ManualURLInfo: Codable {
    let url: String
    let description: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case url, description
        case updatedAt = "updated_at"
    }
}

struct ManualURL: Codable {
    let id: Int
    let manualType: String
    let url: String
    let description: String?
    let updatedBy: Int?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case manualType = "manual_type"
        case url, description
        case updatedBy = "updated_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct UserCreate: Codable {
    let username: String
    let email: String?
    let password: String
    let fullName: String?
    let role: String

    enum CodingKeys: String, CodingKey {
        case username, email, password, role
        case fullName = "full_name"
    }
}
