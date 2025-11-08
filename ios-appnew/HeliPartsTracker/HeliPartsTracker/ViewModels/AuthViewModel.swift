import Foundation
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiService = APIService.shared

    init() {
        checkAuth()
    }

    func checkAuth() {
        if UserDefaults.standard.string(forKey: "authToken") != nil {
            isAuthenticated = true
            // Restore user info from UserDefaults
            if let userData = UserDefaults.standard.data(forKey: "currentUser"),
               let user = try? JSONDecoder().decode(User.self, from: userData) {
                currentUser = user
            }
        }
    }

    func login(username: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await apiService.login(username: username, password: password)
            currentUser = response.user
            isAuthenticated = true

            // Save user info to UserDefaults for persistence
            if let userData = try? JSONEncoder().encode(response.user) {
                UserDefaults.standard.set(userData, forKey: "currentUser")
            }
        } catch {
            errorMessage = "Login failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func logout() {
        apiService.clearToken()
        currentUser = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: "currentUser")
    }
}
