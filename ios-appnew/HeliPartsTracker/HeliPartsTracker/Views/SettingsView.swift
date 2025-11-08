import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var pdfCache = PDFCacheService.shared
    @State private var newLocation = ""
    @State private var showingAddLocation = false
    @State private var showingAddUser = false
    @State private var showingManualURLs = false
    @State private var users: [User] = []
    @State private var isLoadingUsers = false

    // Add User form fields
    @State private var newUsername = ""
    @State private var newPassword = ""
    @State private var newEmail = ""
    @State private var newFullName = ""
    @State private var newUserRole = "user"

    // Manual URL fields
    @State private var r44IPCURL = ""
    @State private var r44MMURL = ""

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
                    DetailRow(label: "Server", value: "https://heli-api.headingshelicopters.org")
                }

                Section(header: Text("Robinson Manuals")) {
                    NavigationLink(destination: ManualURLsSettingsView()) {
                        HStack {
                            Image(systemName: "link.circle.fill")
                                .foregroundColor(.blue)
                                .frame(width: 28)
                            Text("Configure Manual URLs")
                        }
                    }

                    NavigationLink(destination: ManualDownloadsView()) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(.green)
                                .frame(width: 28)
                            VStack(alignment: .leading) {
                                Text("Download Manuals")
                                if pdfCache.isCached(type: .r44IPC) {
                                    let days = pdfCache.daysSinceDownload(type: .r44IPC) ?? 0
                                    Text("Last updated \(days) day\(days == 1 ? "" : "s") ago")
                                        .font(.caption)
                                        .foregroundColor(days > 7 ? .orange : .secondary)
                                }
                            }
                        }
                    }
                }

                Section(header: Text("Maintenance")) {
                    NavigationLink(destination: MaintenanceTemplatesView()) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver")
                                .foregroundColor(.blue)
                                .frame(width: 28)
                            Text("Maintenance Templates")
                        }
                    }
                }

                Section(header: Text("Logbook")) {
                    NavigationLink(destination: LogbookCategoriesView().environmentObject(HelicoptersViewModel())) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.green)
                                .frame(width: 28)
                            Text("Logbook Categories")
                        }
                    }
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

// MARK: - Manual URLs Configuration

struct ManualURLsSettingsView: View {
    @StateObject private var pdfCache = PDFCacheService.shared
    @State private var r44IPCURL: String = ""
    @State private var r44MMURL: String = ""
    @State private var r44PriceListURL: String = ""
    @State private var isSaving = false
    @State private var showingSaveSuccess = false

    var body: some View {
        Form {
            Section(header: Text("R44 Manuals"),
                   footer: Text("Paste Robinson's PDF URLs here. All users will get these URLs.")) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("IPC URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("R44 IPC URL", text: $r44IPCURL, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .lineLimit(3...5)
                        .autocapitalization(.none)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Maintenance Manual URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("R44 MM URL", text: $r44MMURL, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .lineLimit(3...5)
                        .autocapitalization(.none)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Price List URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("R44 Price List URL", text: $r44PriceListURL, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .lineLimit(3...5)
                        .autocapitalization(.none)
                }
            }

            Section {
                Button(action: {
                    Task {
                        await saveURLs()
                    }
                }) {
                    HStack {
                        Spacer()
                        if isSaving {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Saving...")
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Save to Database")
                        }
                        Spacer()
                    }
                }
                .disabled(isSaving)

                Button("Reset to Defaults") {
                    r44IPCURL = PDFCacheService.PDFType.r44IPC.defaultURL
                    r44MMURL = PDFCacheService.PDFType.r44MM.defaultURL
                    r44PriceListURL = PDFCacheService.PDFType.r44PriceList.defaultURL
                }
            }
        }
        .navigationTitle("Manual URLs")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            r44IPCURL = await pdfCache.getConfiguredURL(type: .r44IPC)
            r44MMURL = await pdfCache.getConfiguredURL(type: .r44MM)
            r44PriceListURL = await pdfCache.getConfiguredURL(type: .r44PriceList)
        }
        .alert("Saved to Database", isPresented: $showingSaveSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Manual URLs have been saved to the backend database. All users will receive these URLs.")
        }
    }

    private func saveURLs() async {
        isSaving = true

        do {
            try await pdfCache.saveURL(type: .r44IPC, url: r44IPCURL)
            try await pdfCache.saveURL(type: .r44MM, url: r44MMURL)
            try await pdfCache.saveURL(type: .r44PriceList, url: r44PriceListURL)
            showingSaveSuccess = true
        } catch {
            print("Failed to save URLs: \(error)")
        }

        isSaving = false
    }
}

// MARK: - Manual Downloads Manager

struct ManualDownloadsView: View {
    @StateObject private var pdfCache = PDFCacheService.shared
    @State private var showingDeleteConfirm = false
    @State private var pdfToDelete: PDFCacheService.PDFType?

    var body: some View {
        List {
            Section(header: Text("R44 Manuals"),
                   footer: Text("Downloaded manuals are stored on your device for offline access. Tap download to cache, or refresh to update.")) {
                manualRow(type: .r44IPC)
                manualRow(type: .r44MM)
                manualRow(type: .r44PriceList)
            }
        }
        .navigationTitle("Download Manuals")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Manual?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let type = pdfToDelete {
                    try? pdfCache.deleteCachedPDF(type: type)
                }
            }
        } message: {
            if let type = pdfToDelete {
                Text("This will delete the cached \(type.rawValue). You can re-download it anytime.")
            }
        }
    }

    private func manualRow(type: PDFCacheService.PDFType) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(type.rawValue)
                    .font(.headline)

                if pdfCache.isCached(type: type) {
                    if let days = pdfCache.daysSinceDownload(type: type) {
                        Text("Downloaded \(days) day\(days == 1 ? "" : "s") ago")
                            .font(.caption)
                            .foregroundColor(days > 7 ? .orange : .secondary)
                        if days > 7 {
                            Text("⚠️ Consider updating")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                } else {
                    Text("Not downloaded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if pdfCache.isCached(type: type) {
                Button(action: {
                    pdfToDelete = type
                    showingDeleteConfirm = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }

            Button(action: {
                Task {
                    let url = await pdfCache.getConfiguredURL(type: type)
                    try? await pdfCache.downloadPDF(type: type, fromURL: url)
                }
            }) {
                if pdfCache.isDownloading {
                    ProgressView()
                } else {
                    Image(systemName: pdfCache.isCached(type: type) ? "arrow.clockwise" : "arrow.down.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .buttonStyle(.borderless)
        }
    }
}

