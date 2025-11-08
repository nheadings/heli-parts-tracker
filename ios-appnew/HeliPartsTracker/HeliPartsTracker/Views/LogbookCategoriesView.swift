import SwiftUI
import Combine

struct LogbookCategoriesView: View {
    @StateObject private var viewModel = LogbookCategoriesViewModel()
    @State private var showingAddCategory = false
    @State private var editingCategory: LogbookCategory? = nil

    var body: some View {
        List {
            ForEach(viewModel.categories) { category in
                HStack {
                    Image(systemName: category.icon)
                        .foregroundColor(Color(hex: category.color))
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.name)
                            .font(.body)
                        Text("Order: \(category.displayOrder)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if !category.isActive {
                        Text("Disabled")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    editingCategory = category
                }
            }
            .onDelete(perform: deleteCategories)
            .onMove(perform: moveCategories)
        }
        .navigationTitle("Logbook Categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddCategory = true }) {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
        }
        .task {
            await viewModel.loadCategories()
        }
        .sheet(isPresented: $showingAddCategory) {
            EditLogbookCategoryView(onSave: {
                Task {
                    await viewModel.loadCategories()
                }
            })
        }
        .sheet(item: $editingCategory) { category in
            EditLogbookCategoryView(category: category, onSave: {
                Task {
                    await viewModel.loadCategories()
                }
            })
        }
    }

    private func deleteCategories(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let category = viewModel.categories[index]
                await viewModel.deleteCategory(id: category.id)
            }
        }
    }

    private func moveCategories(from source: IndexSet, to destination: Int) {
        var updatedCategories = viewModel.categories
        updatedCategories.move(fromOffsets: source, toOffset: destination)

        // Update display_order for all categories
        Task {
            for (index, category) in updatedCategories.enumerated() {
                let categoryCreate = LogbookCategoryCreate(
                    name: category.name,
                    icon: category.icon,
                    color: category.color,
                    displayOrder: index
                )
                _ = try? await APIService.shared.updateLogbookCategory(
                    id: category.id,
                    category: categoryCreate,
                    isActive: category.isActive,
                    displayInFlightView: category.displayInFlightView ?? false,
                    intervalHours: category.intervalHours,
                    thresholdWarning: category.thresholdWarning
                )
            }
            await viewModel.loadCategories()
        }
    }
}

struct EditLogbookCategoryView: View {
    let category: LogbookCategory?
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedIcon = "wrench.fill"
    @State private var selectedColor = Color.blue
    @State private var displayOrder = 0
    @State private var isActive = true
    @State private var displayInFlightView = false
    @State private var intervalHours = ""
    @State private var thresholdWarning = 25
    @State private var selectedHelicopterIds: Set<Int> = []
    @State private var showingHelicopterPicker = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingIconPicker = false

    @EnvironmentObject var helicoptersViewModel: HelicoptersViewModel

    init(category: LogbookCategory? = nil, onSave: @escaping () -> Void) {
        self.category = category
        self.onSave = onSave
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Category Details") {
                    TextField("Name", text: $name)

                    HStack {
                        Text("Icon")
                        Spacer()
                        Button(action: { showingIconPicker = true }) {
                            HStack {
                                Image(systemName: selectedIcon)
                                    .foregroundColor(selectedColor)
                                Text(selectedIcon)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    ColorPicker("Color", selection: $selectedColor, supportsOpacity: false)

                    Stepper("Display Order: \(displayOrder)", value: $displayOrder, in: 0...100)
                }

                Section {
                    Toggle("Active", isOn: $isActive)
                }

                Section("Flight View Banner") {
                    Toggle("Show as Banner", isOn: $displayInFlightView)

                    if displayInFlightView {
                        HStack {
                            Text("Interval Hours")
                            Spacer()
                            TextField("", text: $intervalHours)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                        }

                        Stepper("Warning Threshold: \(thresholdWarning) hrs", value: $thresholdWarning, in: 1...100)

                        Button(action: { showingHelicopterPicker = true }) {
                            HStack {
                                Text("Assign to Aircraft")
                                Spacer()
                                if selectedHelicopterIds.isEmpty {
                                    Text("None")
                                        .foregroundColor(.red)
                                } else if selectedHelicopterIds.count == helicoptersViewModel.helicopters.count {
                                    Text("All")
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("\(selectedHelicopterIds.count) selected")
                                        .foregroundColor(.secondary)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
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
            .navigationTitle(category == nil ? "Add Category" : "Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await save()
                        }
                    }
                    .disabled(isSaving || name.isEmpty || (displayInFlightView && intervalHours.isEmpty) || (displayInFlightView && selectedHelicopterIds.isEmpty))
                }
            }
        }
        .onAppear {
            loadExisting()
        }
        .sheet(isPresented: $showingIconPicker) {
            IconPickerView(selectedIcon: $selectedIcon)
        }
        .sheet(isPresented: $showingHelicopterPicker) {
            NavigationView {
                Form {
                    Section("Select Aircraft for This Banner") {
                        Toggle("All Aircraft", isOn: Binding(
                            get: {
                                // All is ON only if all helicopters are selected
                                selectedHelicopterIds.count == helicoptersViewModel.helicopters.count
                            },
                            set: { isOn in
                                if isOn {
                                    // Turn on all
                                    selectedHelicopterIds = Set(helicoptersViewModel.helicopters.map { $0.id })
                                } else {
                                    // Turn off all
                                    selectedHelicopterIds = []
                                }
                            }
                        ))
                        .onChange(of: selectedHelicopterIds) {
                            // If user selected all manually, check "All Aircraft" too
                            if selectedHelicopterIds.count == helicoptersViewModel.helicopters.count && !selectedHelicopterIds.isEmpty {
                                // Already all selected, toggle is synced
                            }
                        }

                        ForEach(helicoptersViewModel.helicopters) { heli in
                            Toggle(heli.tailNumber, isOn: Binding(
                                get: { selectedHelicopterIds.contains(heli.id) },
                                set: { isOn in
                                    if isOn {
                                        selectedHelicopterIds.insert(heli.id)
                                    } else {
                                        selectedHelicopterIds.remove(heli.id)
                                    }
                                }
                            ))
                        }
                    }
                }
                .navigationTitle("Select Aircraft")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingHelicopterPicker = false
                        }
                    }
                }
                .task {
                    await helicoptersViewModel.loadHelicopters()
                }
            }
        }
    }

    private func loadExisting() {
        if let category = category {
            name = category.name
            selectedIcon = category.icon
            selectedColor = Color(hex: category.color)
            displayOrder = category.displayOrder
            isActive = category.isActive
            displayInFlightView = category.displayInFlightView ?? false
            if let hours = category.intervalHours {
                intervalHours = String(format: "%.1f", hours)
            }
            thresholdWarning = category.thresholdWarning ?? 25
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil

        let categoryCreate = LogbookCategoryCreate(
            name: name,
            icon: selectedIcon,
            color: selectedColor.toHex(),
            displayOrder: displayOrder
        )

        do {
            let savedCategory: LogbookCategory
            if let existing = category {
                savedCategory = try await APIService.shared.updateLogbookCategory(
                    id: existing.id,
                    category: categoryCreate,
                    isActive: isActive,
                    displayInFlightView: displayInFlightView,
                    intervalHours: intervalHours.isEmpty ? nil : Double(intervalHours),
                    thresholdWarning: displayInFlightView ? thresholdWarning : nil
                )
            } else {
                savedCategory = try await APIService.shared.createLogbookCategory(category: categoryCreate)
            }

            // Save helicopter assignments if banner is enabled
            if displayInFlightView {
                try await saveHelicopterAssignments(categoryId: savedCategory.id)
            }

            onSave()
            dismiss()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }

        isSaving = false
    }

    private func saveHelicopterAssignments(categoryId: Int) async throws {
        struct UpdateBody: Codable {
            let helicopter_ids: [Int]
        }

        // If all selected or none selected, send empty array (show to all)
        let allHelicopterIds = Set(helicoptersViewModel.helicopters.map { $0.id })
        let helicopterIdsArray: [Int]

        if selectedHelicopterIds.isEmpty || selectedHelicopterIds == allHelicopterIds {
            helicopterIdsArray = []
        } else {
            helicopterIdsArray = Array(selectedHelicopterIds)
        }

        let body = UpdateBody(helicopter_ids: helicopterIdsArray)
        let url = URL(string: "http://192.168.68.6:3000/api/unified-logbook/categories/\(categoryId)/helicopters")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = UserDefaults.standard.string(forKey: "authToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONEncoder().encode(body)
        let (_, _) = try await URLSession.shared.data(for: request)
    }
}

// MARK: - Icon Picker

struct IconPickerView: View {
    @Binding var selectedIcon: String
    @Environment(\.dismiss) private var dismiss

    let commonIcons = [
        "wrench.fill", "drop.fill", "checkmark.seal.fill", "drop.triangle.fill",
        "cube.box.fill", "airplane", "clock.fill", "exclamationmark.triangle.fill",
        "gear", "hammer.fill", "screwdriver.fill", "sparkplug.fill",
        "engine.combustion.fill", "fuelpump.fill", "oilcan.fill", "battery.100.bolt",
        "smoke.fill", "wind", "gauge.with.dots.needle.bottom.50percent", "speedometer",
        "calendar", "bell.fill", "doc.text.fill", "folder.fill",
        "person.fill", "star.fill", "flag.fill", "bookmark.fill"
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 20) {
                    ForEach(commonIcons, id: \.self) { icon in
                        Button(action: {
                            selectedIcon = icon
                            dismiss()
                        }) {
                            VStack {
                                Image(systemName: icon)
                                    .font(.title)
                                    .frame(width: 50, height: 50)
                                    .foregroundColor(selectedIcon == icon ? .blue : .primary)
                                    .background(selectedIcon == icon ? Color.blue.opacity(0.2) : Color.clear)
                                    .cornerRadius(10)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Select Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
class LogbookCategoriesViewModel: ObservableObject {
    @Published var categories: [LogbookCategory] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadCategories() async {
        isLoading = true
        do {
            categories = try await APIService.shared.getLogbookCategories()
        } catch {
            errorMessage = "Failed to load categories: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func deleteCategory(id: Int) async {
        do {
            try await APIService.shared.deleteLogbookCategory(id: id)
            await loadCategories()
        } catch {
            errorMessage = "Failed to delete category: \(error.localizedDescription)"
        }
    }
}
