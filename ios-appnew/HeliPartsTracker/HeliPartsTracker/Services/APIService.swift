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
        try await performRequest(endpoint: "/parts/alerts/low-stock", method: "GET")
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

    func updateInstallation(id: Int, serialNumber: String?, hoursAtInstallation: Double?, notes: String?) async throws -> PartInstallation {
        struct UpdateBody: Codable {
            let serial_number: String?
            let hours_at_installation: Double?
            let notes: String?
        }

        let body = UpdateBody(
            serial_number: serialNumber,
            hours_at_installation: hoursAtInstallation,
            notes: notes
        )

        return try await performRequest(endpoint: "/installations/\(id)", method: "PUT", body: body)
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

    // MARK: - Logbook

    // Helicopter Hours
    func getHelicopterHours(helicopterId: Int, limit: Int = 50) async throws -> HelicopterHoursResponse {
        try await performRequest(endpoint: "/logbook/helicopters/\(helicopterId)/hours?limit=\(limit)", method: "GET")
    }

    func updateHelicopterHours(helicopterId: Int, hours: HelicopterHoursCreate) async throws -> HelicopterHours {
        try await performRequest(endpoint: "/logbook/helicopters/\(helicopterId)/hours", method: "POST", body: hours)
    }

    func updateHoursEntry(id: Int, hours: HelicopterHoursCreate) async throws -> HelicopterHours {
        try await performRequest(endpoint: "/logbook/hours/\(id)", method: "PUT", body: hours)
    }

    // Maintenance Logs
    func getMaintenanceLogs(helicopterId: Int, logType: String? = nil) async throws -> [MaintenanceLog] {
        var endpoint = "/logbook/helicopters/\(helicopterId)/maintenance"
        if let type = logType {
            endpoint += "?type=\(type)"
        }
        return try await performRequest(endpoint: endpoint, method: "GET")
    }

    func createMaintenanceLog(helicopterId: Int, log: MaintenanceLogCreate) async throws -> MaintenanceLog {
        try await performRequest(endpoint: "/logbook/helicopters/\(helicopterId)/maintenance", method: "POST", body: log)
    }

    func updateMaintenanceLog(id: Int, log: MaintenanceLogCreate) async throws -> MaintenanceLog {
        try await performRequest(endpoint: "/logbook/maintenance/\(id)", method: "PUT", body: log)
    }

    func deleteMaintenanceLog(id: Int) async throws {
        let _: EmptyResponse = try await performRequest(endpoint: "/logbook/maintenance/\(id)", method: "DELETE")
    }

    // Fluid Logs
    func getFluidLogs(helicopterId: Int, fluidType: String? = nil) async throws -> [FluidLog] {
        var endpoint = "/logbook/helicopters/\(helicopterId)/fluids"
        if let type = fluidType {
            endpoint += "?type=\(type)"
        }
        return try await performRequest(endpoint: endpoint, method: "GET")
    }

    func createFluidLog(helicopterId: Int, log: FluidLogCreate) async throws -> FluidLog {
        try await performRequest(endpoint: "/logbook/helicopters/\(helicopterId)/fluids", method: "POST", body: log)
    }

    func updateFluidLog(id: Int, log: FluidLogCreate) async throws -> FluidLog {
        try await performRequest(endpoint: "/logbook/fluids/\(id)", method: "PUT", body: log)
    }

    func deleteFluidLog(id: Int) async throws {
        let _: EmptyResponse = try await performRequest(endpoint: "/logbook/fluids/\(id)", method: "DELETE")
    }

    // Life Limited Parts
    func getLifeLimitedParts(helicopterId: Int) async throws -> [LifeLimitedPart] {
        try await performRequest(endpoint: "/logbook/helicopters/\(helicopterId)/life-limited-parts", method: "GET")
    }

    func createLifeLimitedPart(part: LifeLimitedPartCreate) async throws -> LifeLimitedPart {
        try await performRequest(endpoint: "/logbook/life-limited-parts", method: "POST", body: part)
    }

    func updateLifeLimitedPart(id: Int, part: LifeLimitedPartCreate) async throws -> LifeLimitedPart {
        try await performRequest(endpoint: "/logbook/life-limited-parts/\(id)", method: "PUT", body: part)
    }

    func removeLifeLimitedPart(id: Int) async throws {
        let _: EmptyResponse = try await performRequest(endpoint: "/logbook/life-limited-parts/\(id)/remove", method: "POST")
    }

    // Maintenance Schedules
    func getMaintenanceScheduleTemplates() async throws -> [MaintenanceSchedule] {
        try await performRequest(endpoint: "/logbook/maintenance-schedules/templates", method: "GET")
    }

    func getHelicopterSchedules(helicopterId: Int) async throws -> [MaintenanceSchedule] {
        try await performRequest(endpoint: "/logbook/helicopters/\(helicopterId)/schedules", method: "GET")
    }

    func createMaintenanceSchedule(schedule: MaintenanceScheduleCreate) async throws -> MaintenanceSchedule {
        try await performRequest(endpoint: "/logbook/maintenance-schedules", method: "POST", body: schedule)
    }

    func updateMaintenanceSchedule(id: Int, schedule: MaintenanceScheduleCreate) async throws -> MaintenanceSchedule {
        try await performRequest(endpoint: "/logbook/maintenance-schedules/\(id)", method: "PUT", body: schedule)
    }

    func deleteMaintenanceSchedule(id: Int) async throws {
        let _: EmptyResponse = try await performRequest(endpoint: "/logbook/maintenance-schedules/\(id)", method: "DELETE")
    }

    // Dashboard
    func getLogbookDashboard(helicopterId: Int) async throws -> LogbookDashboard {
        try await performRequest(endpoint: "/logbook/helicopters/\(helicopterId)/dashboard", method: "GET")
    }

    // MARK: - Flights

    func getFlights(helicopterId: Int, limit: Int = 50) async throws -> [Flight] {
        try await performRequest(endpoint: "/helicopters/\(helicopterId)/flights?limit=\(limit)", method: "GET")
    }

    func getFlight(id: Int) async throws -> Flight {
        try await performRequest(endpoint: "/flights/\(id)", method: "GET")
    }

    func createFlight(helicopterId: Int, flight: FlightCreate) async throws -> Flight {
        try await performRequest(endpoint: "/helicopters/\(helicopterId)/flights", method: "POST", body: flight)
    }

    func updateFlight(id: Int, flight: FlightCreate) async throws -> Flight {
        try await performRequest(endpoint: "/flights/\(id)", method: "PUT", body: flight)
    }

    func deleteFlight(id: Int) async throws {
        let _: EmptyResponse = try await performRequest(endpoint: "/flights/\(id)", method: "DELETE")
    }

    // MARK: - Squawks

    func getSquawks(helicopterId: Int, status: String? = nil, severity: String? = nil) async throws -> [Squawk] {
        var endpoint = "/helicopters/\(helicopterId)/squawks"
        var queryParams: [String] = []

        if let status = status {
            queryParams.append("status=\(status)")
        }
        if let severity = severity {
            queryParams.append("severity=\(severity)")
        }

        if !queryParams.isEmpty {
            endpoint += "?" + queryParams.joined(separator: "&")
        }

        return try await performRequest(endpoint: endpoint, method: "GET")
    }

    func getSquawk(id: Int) async throws -> Squawk {
        try await performRequest(endpoint: "/squawks/\(id)", method: "GET")
    }

    func createSquawk(helicopterId: Int, squawk: SquawkCreate) async throws -> Squawk {
        try await performRequest(endpoint: "/helicopters/\(helicopterId)/squawks", method: "POST", body: squawk)
    }

    func updateSquawk(id: Int, squawk: SquawkUpdate) async throws -> Squawk {
        try await performRequest(endpoint: "/squawks/\(id)", method: "PUT", body: squawk)
    }

    func markSquawkFixed(id: Int, fixNotes: String?) async throws -> Squawk {
        let body = SquawkFixRequest(fixNotes: fixNotes)
        return try await performRequest(endpoint: "/squawks/\(id)/fix", method: "PUT", body: body)
    }

    func updateSquawkStatus(id: Int, status: String) async throws -> Squawk {
        let body = SquawkStatusUpdate(status: status)
        return try await performRequest(endpoint: "/squawks/\(id)/status", method: "PUT", body: body)
    }

    func deleteSquawk(id: Int) async throws {
        let _: EmptyResponse = try await performRequest(endpoint: "/squawks/\(id)", method: "DELETE")
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
