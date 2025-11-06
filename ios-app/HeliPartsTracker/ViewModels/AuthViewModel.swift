import Foundation

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
        }
    }

    func login(username: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await apiService.login(username: username, password: password)
            currentUser = response.user
            isAuthenticated = true
        } catch {
            errorMessage = "Login failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func logout() {
        apiService.clearToken()
        currentUser = nil
        isAuthenticated = false
    }
}
