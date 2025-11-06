import Foundation

class APIService {
    static let shared = APIService()

    private let baseURL = "http://192.168.68.6:3000/api"
    private var authToken: String?

    private init() {
        // Load saved token
        authToken = UserDefaults.standard.string(forKey: "authToken")
    }

    func saveToken(_ token: String) {
        authToken = token
        UserDefaults.standard.set(token, forKey: "authToken")
    }

    func clearToken() {
        authToken = nil
        UserDefaults.standard.removeObject(forKey: "authToken")
    }

    // MARK: - Auth

    func login(username: String, password: String) async throws -> LoginResponse {
        let url = URL(string: "\(baseURL)/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["username": username, "password": password]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }

        let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
        saveToken(loginResponse.token)
        return loginResponse
    }

    // MARK: - Parts

    func getParts() async throws -> [Part] {
        try await performRequest(endpoint: "/parts", method: "GET")
    }

    func searchParts(query: String) async throws -> [Part] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return try await performRequest(endpoint: "/parts/search?q=\(encodedQuery)", method: "GET")
    }

    func getPart(id: Int) async throws -> Part {
        try await performRequest(endpoint: "/parts/\(id)", method: "GET")
    }

    func createPart(_ part: PartCreate) async throws -> Part {
        try await performRequest(endpoint: "/parts", method: "POST", body: part)
    }

    func updatePart(id: Int, _ part: PartCreate) async throws -> Part {
        try await performRequest(endpoint: "/parts/\(id)", method: "PUT", body: part)
    }

    func deletePart(id: Int) async throws {
        let _: EmptyResponse = try await performRequest(endpoint: "/parts/\(id)", method: "DELETE")
    }

    func getLowStockParts() async throws -> [Part] {
        try await performRequest(endpoint: "/parts/low-stock", method: "GET")
    }

    // MARK: - Helicopters

    func getHelicopters() async throws -> [Helicopter] {
        try await performRequest(endpoint: "/helicopters", method: "GET")
    }

    func getHelicopter(id: Int) async throws -> Helicopter {
        try await performRequest(endpoint: "/helicopters/\(id)", method: "GET")
    }

    func getHelicopterParts(id: Int) async throws -> [PartInstallation] {
        try await performRequest(endpoint: "/helicopters/\(id)/parts", method: "GET")
    }

    func createHelicopter(_ helicopter: HelicopterCreate) async throws -> Helicopter {
        try await performRequest(endpoint: "/helicopters", method: "POST", body: helicopter)
    }

    func updateHelicopter(id: Int, _ helicopter: HelicopterCreate) async throws -> Helicopter {
        try await performRequest(endpoint: "/helicopters/\(id)", method: "PUT", body: helicopter)
    }

    func deleteHelicopter(id: Int) async throws {
        let _: EmptyResponse = try await performRequest(endpoint: "/helicopters/\(id)", method: "DELETE")
    }

    // MARK: - Installations

    func installPart(partId: Int, helicopterId: Int, quantity: Int, notes: String?) async throws -> PartInstallation {
        struct InstallBody: Codable {
            let part_id: Int
            let helicopter_id: Int
            let quantity_installed: Int
            let notes: String?
        }

        let body = InstallBody(
            part_id: partId,
            helicopter_id: helicopterId,
            quantity_installed: quantity,
            notes: notes
        )

        return try await performRequest(endpoint: "/installations", method: "POST", body: body)
    }

    func removeInstallation(id: Int) async throws {
        struct RemoveBody: Codable {
            let return_to_stock: Bool
        }

        let body = RemoveBody(return_to_stock: true)
        let _: EmptyResponse = try await performRequest(endpoint: "/installations/\(id)/remove", method: "POST", body: body)
    }

    // MARK: - Users

    func getUsers() async throws -> [User] {
        try await performRequest(endpoint: "/auth/users", method: "GET")
    }

    func registerUser(_ userData: UserCreate) async throws -> User {
        struct RegisterResponse: Codable {
            let user: User
        }
        let response: RegisterResponse = try await performRequest(endpoint: "/auth/register", method: "POST", body: userData)
        return response.user
    }

    // MARK: - Transactions

    func getPartTransactions(partId: Int) async throws -> [InventoryTransaction] {
        try await performRequest(endpoint: "/parts/\(partId)/transactions", method: "GET")
    }

    // MARK: - Generic Request

    private func performRequest<T: Decodable>(endpoint: String, method: String, body: Encodable? = nil) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            throw APIError.serverError(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

enum APIError: Error {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case decodingError
}

struct EmptyResponse: Codable {}
