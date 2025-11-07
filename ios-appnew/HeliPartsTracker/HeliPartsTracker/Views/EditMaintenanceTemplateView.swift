import SwiftUI

struct EditMaintenanceTemplateView: View {
    @Environment(\.dismiss) var dismiss
    @State private var title: String
    @State private var description: String
    @State private var intervalHours: String
    @State private var category: String
    @State private var selectedColor: Color
    @State private var displayOrder: Int
    @State private var displayInFlightView: Bool
    @State private var thresholdWarning: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var helicopters: [Helicopter] = []
    @State private var selectedHelicopterIds: Set<Int> = []

    let template: MaintenanceSchedule?
    let onSave: () -> Void

    private let categories = ["service", "ad_compliance", "inspection", "overhaul"]
    private let presetColors: [Color] = [
        Color(hex: "#FF3B30"), // Red
        Color(hex: "#FF9500"), // Orange
        Color(hex: "#FFCC00"), // Yellow
        Color(hex: "#34C759"), // Green
        Color(hex: "#007AFF"), // Blue
        Color(hex: "#5856D6"), // Purple
        Color(hex: "#FF2D55"), // Pink
        Color(hex: "#5AC8FA")  // Light Blue
    ]

    init(template: MaintenanceSchedule? = nil, onSave: @escaping () -> Void) {
        self.template = template
        self.onSave = onSave

        _title = State(initialValue: template?.title ?? "")
        _description = State(initialValue: template?.description ?? "")
        _intervalHours = State(initialValue: template?.intervalHours != nil ? String(Int(template!.intervalHours!)) : "100")
        _category = State(initialValue: template?.category ?? "service")
        _selectedColor = State(initialValue: Color(hex: template?.color ?? "#34C759"))
        _displayOrder = State(initialValue: template?.displayOrder ?? 0)
        _displayInFlightView = State(initialValue: template?.displayInFlightView ?? false)
        _thresholdWarning = State(initialValue: template?.thresholdWarning != nil ? String(template!.thresholdWarning!) : "10")
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic Information")) {
                    TextField("Title", text: $title)
                    TextField("Description (optional)", text: $description)

                    Picker("Category", selection: $category) {
                        Text("Service").tag("service")
                        Text("AD Compliance").tag("ad_compliance")
                        Text("Inspection").tag("inspection")
                        Text("Overhaul").tag("overhaul")
                    }
                }

                Section(header: Text("Interval Settings")) {
                    HStack {
                        TextField("Hours", text: $intervalHours)
                            .keyboardType(.numberPad)
                        Text("hours")
                            .foregroundColor(.gray)
                    }

                    HStack {
                        TextField("Warning Threshold", text: $thresholdWarning)
                            .keyboardType(.numberPad)
                        Text("hours before due")
                            .foregroundColor(.gray)
                    }
                }

                Section(header: Text("Display Settings")) {
                    Toggle("Show in Flight View", isOn: $displayInFlightView)

                    if displayInFlightView {
                        Stepper("Display Order: \(displayOrder + 1)", value: $displayOrder, in: 0...4)
                            .font(.subheadline)
                    }
                }

                Section(header: Text("Color")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 16) {
                        ForEach(presetColors, id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(selectedColor.toHex() == color.toHex() ? Color.primary : Color.clear, lineWidth: 3)
                                )
                                .onTapGesture {
                                    selectedColor = color
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section(header: Text("Assign to Aircraft")) {
                    if helicopters.isEmpty {
                        Text("Loading aircraft...")
                            .foregroundColor(.secondary)
                    } else {
                        Text("All ON = Show on all aircraft\nTurn OFF specific aircraft to exclude them")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ForEach(helicopters) { helicopter in
                            Toggle(helicopter.tailNumber, isOn: Binding(
                                get: { selectedHelicopterIds.contains(helicopter.id) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedHelicopterIds.insert(helicopter.id)
                                    } else {
                                        selectedHelicopterIds.remove(helicopter.id)
                                    }
                                }
                            ))
                        }
                    }
                }

                if let template = template {
                    Section {
                        Button(role: .destructive, action: deleteTemplate) {
                            HStack {
                                Spacer()
                                if isLoading {
                                    ProgressView()
                                } else {
                                    Text("Delete Template")
                                }
                                Spacer()
                            }
                        }
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(template == nil ? "New Template" : "Edit Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveTemplate()
                        }
                    }
                    .disabled(title.isEmpty || intervalHours.isEmpty || isLoading)
                }
            }
        }
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        // Load helicopters
        do {
            helicopters = try await APIService.shared.getHelicopters()

            // Load assigned helicopters if editing
            if let template = template {
                do {
                    let assignments = try await APIService.shared.getTemplateHelicopters(templateId: template.id)
                    if assignments.isEmpty {
                        // No assignments = show to all = all toggles ON
                        selectedHelicopterIds = Set(helicopters.map { $0.id })
                    } else {
                        // Specific assignments
                        selectedHelicopterIds = Set(assignments.map { $0.id })
                    }
                } catch {
                    print("Failed to load helicopter assignments: \(error)")
                    // Default to all selected (show to all)
                    selectedHelicopterIds = Set(helicopters.map { $0.id })
                }
            } else {
                // New template - default to all selected (show to all)
                selectedHelicopterIds = Set(helicopters.map { $0.id })
            }
        } catch {
            print("Failed to load helicopters: \(error)")
        }
    }

    private func saveTemplate() async {
        isLoading = true
        errorMessage = nil

        guard let hours = Double(intervalHours),
              let threshold = Int(thresholdWarning) else {
            errorMessage = "Please enter valid numbers"
            isLoading = false
            return
        }

        do {
            var templateId: Int

            if let existingTemplate = template {
                // Update existing template - send raw JSON with is_active field
                let updateData: [String: Any] = [
                    "title": title,
                    "description": description.isEmpty ? "" : description,
                    "interval_hours": hours,
                    "interval_days": NSNull(),
                    "category": category,
                    "is_active": true,
                    "color": selectedColor.toHex(),
                    "display_order": displayOrder,
                    "display_in_flight_view": displayInFlightView,
                    "threshold_warning": threshold
                ]

                let jsonData = try JSONSerialization.data(withJSONObject: updateData)
                let url = URL(string: "http://192.168.68.6:3000/api/logbook/maintenance-schedules/\(existingTemplate.id)")!
                var request = URLRequest(url: url)
                request.httpMethod = "PUT"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                if let token = UserDefaults.standard.string(forKey: "authToken") {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }

                request.httpBody = jsonData
                let (_, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Update failed"])
                }

                templateId = existingTemplate.id
            } else {
                // Create new template
                let scheduleData = MaintenanceScheduleCreate(
                    title: title,
                    description: description.isEmpty ? nil : description,
                    intervalHours: hours,
                    intervalDays: nil,
                    helicopterId: nil,
                    category: category,
                    color: selectedColor.toHex(),
                    displayOrder: displayOrder,
                    displayInFlightView: displayInFlightView,
                    thresholdWarning: threshold,
                    isTemplate: true
                )
                let newTemplate = try await APIService.shared.createMaintenanceSchedule(schedule: scheduleData)
                templateId = newTemplate.id
            }

            // Save helicopter assignments
            // If ALL helicopters are selected, save empty array (show to all)
            // If only some are selected, save those specific IDs
            let allHelicopterIds = Set(helicopters.map { $0.id })
            let helicopterIdsArray: [Int]

            if selectedHelicopterIds == allHelicopterIds {
                // All selected = show to all = empty array
                helicopterIdsArray = []
            } else {
                // Specific helicopters selected
                helicopterIdsArray = Array(selectedHelicopterIds)
            }

            do {
                try await APIService.shared.updateTemplateHelicopters(templateId: templateId, helicopterIds: helicopterIdsArray)
            } catch {
                // Show detailed error for helicopter assignments
                print("Helicopter assignment error: \(error)")
                errorMessage = "Failed to save aircraft assignments: \(error.localizedDescription)\nTemplate ID: \(templateId), Aircraft IDs: \(helicopterIdsArray)"
                isLoading = false
                return
            }

            onSave()
            dismiss()
        } catch {
            errorMessage = "Failed to save template: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func deleteTemplate() {
        guard let template = template else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await APIService.shared.deleteMaintenanceSchedule(id: template.id)
                onSave()
                dismiss()
            } catch {
                errorMessage = "Failed to delete: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}
