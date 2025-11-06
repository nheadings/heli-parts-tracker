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
