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
                    isActive: category.isActive
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
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingIconPicker = false

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
                    .disabled(isSaving || name.isEmpty)
                }
            }
        }
        .onAppear {
            loadExisting()
        }
        .sheet(isPresented: $showingIconPicker) {
            IconPickerView(selectedIcon: $selectedIcon)
        }
    }

    private func loadExisting() {
        if let category = category {
            name = category.name
            selectedIcon = category.icon
            selectedColor = Color(hex: category.color)
            displayOrder = category.displayOrder
            isActive = category.isActive
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
            if let existing = category {
                _ = try await APIService.shared.updateLogbookCategory(
                    id: existing.id,
                    category: categoryCreate,
                    isActive: isActive
                )
            } else {
                _ = try await APIService.shared.createLogbookCategory(category: categoryCreate)
            }

            onSave()
            dismiss()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }

        isSaving = false
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
