import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var locationManager = LocationManager.shared
    @State private var newLocation = ""
    @State private var showingAddLocation = false
    @State private var showingAddUser = false
    @State private var users: [User] = []
    @State private var isLoadingUsers = false

    // Add User form fields
    @State private var newUsername = ""
    @State private var newPassword = ""
    @State private var newEmail = ""
    @State private var newFullName = ""
    @State private var newUserRole = "user"

    var body: some View {
        NavigationView {
            List {
                if let user = authViewModel.currentUser {
                    Section("Account") {
                        DetailRow(label: "Username", value: user.username)
                        if let email = user.email {
                            DetailRow(label: "Email", value: email)
                        }
                        if let fullName = user.fullName {
                            DetailRow(label: "Name", value: fullName)
                        }
                        DetailRow(label: "Role", value: user.role.capitalized)
                    }
                }

                Section("App Information") {
                    DetailRow(label: "Version", value: "1.0.0")
                    DetailRow(label: "Server", value: "192.168.68.6:3000")
                }

                Section(header: Text("Part Locations")) {
                    ForEach(locationManager.locations, id: \.self) { location in
                        Text(location)
                    }
                    .onDelete(perform: deleteLocations)

                    Button(action: {
                        showingAddLocation = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("Add Location")
                        }
                    }
                }

                Section(header: Text("Users")) {
                    if isLoadingUsers {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        ForEach(users) { user in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.username)
                                    .font(.headline)
                                if let fullName = user.fullName {
                                    Text(fullName)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Text(user.role.capitalized)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .padding(.vertical, 4)
                        }

                        Button(action: {
                            showingAddUser = true
                        }) {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                    .foregroundColor(.green)
                                Text("Add User")
                            }
                        }
                    }
                }

                Section {
                    Button(role: .destructive, action: {
                        authViewModel.logout()
                    }) {
                        HStack {
                            Spacer()
                            Text("Logout")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .task {
                await loadUsers()
            }
            .sheet(isPresented: $showingAddLocation) {
                NavigationView {
                    Form {
                        Section("New Location") {
                            TextField("Location name", text: $newLocation)
                        }
                    }
                    .navigationTitle("Add Location")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                showingAddLocation = false
                                newLocation = ""
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Add") {
                                locationManager.addLocation(newLocation)
                                showingAddLocation = false
                                newLocation = ""
                            }
                            .disabled(newLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddUser) {
                NavigationView {
                    Form {
                        Section("User Information") {
                            TextField("Username", text: $newUsername)
                                .autocapitalization(.none)
                            SecureField("Password", text: $newPassword)
                            TextField("Email (optional)", text: $newEmail)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                            TextField("Full Name (optional)", text: $newFullName)
                        }

                        Section("Role") {
                            Picker("Role", selection: $newUserRole) {
                                Text("User").tag("user")
                                Text("Admin").tag("admin")
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .navigationTitle("Add User")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                showingAddUser = false
                                resetUserForm()
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Add") {
                                Task {
                                    await addUser()
                                }
                            }
                            .disabled(newUsername.isEmpty || newPassword.isEmpty)
                        }
                    }
                }
            }
        }
    }

    private func deleteLocations(at offsets: IndexSet) {
        for index in offsets {
            let location = locationManager.locations[index]
            locationManager.removeLocation(location)
        }
    }

    private func loadUsers() async {
        isLoadingUsers = true
        do {
            users = try await APIService.shared.getUsers()
        } catch {
            print("Failed to load users: \(error)")
        }
        isLoadingUsers = false
    }

    private func addUser() async {
        let userData = UserCreate(
            username: newUsername,
            email: newEmail.isEmpty ? nil : newEmail,
            password: newPassword,
            fullName: newFullName.isEmpty ? nil : newFullName,
            role: newUserRole
        )

        do {
            let newUser = try await APIService.shared.registerUser(userData)
            users.append(newUser)
            users.sort { $0.username < $1.username }
            showingAddUser = false
            resetUserForm()
        } catch {
            print("Failed to add user: \(error)")
        }
    }

    private func resetUserForm() {
        newUsername = ""
        newPassword = ""
        newEmail = ""
        newFullName = ""
        newUserRole = "user"
    }
}
