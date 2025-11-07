import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct AddLogbookEntryView: View {
    let existingEntry: LogbookEntryDetail?
    let defaultHelicopterId: Int?
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var helicoptersViewModel: HelicoptersViewModel
    @EnvironmentObject var viewModel: UnifiedLogbookViewModel

    @State private var selectedHelicopterId: Int = 0
    @State private var selectedCategoryId: Int = 0
    @State private var eventDate = Date()
    @State private var hoursAtEvent = ""
    @State private var description = ""
    @State private var notes = ""
    @State private var cost = ""
    @State private var nextDueHours = ""
    @State private var nextDueDate: Date? = nil
    @State private var includeNextDueDate = false

    @State private var selectedPhotos: [UIImage] = []
    @State private var selectedDocuments: [URL] = []
    @State private var existingAttachments: [LogbookAttachment] = []
    @State private var showingCamera = false
    @State private var showingImagePicker = false
    @State private var showingDocumentPicker = false
    @State private var showingCategoryPicker = false
    @State private var showingDateTimePicker = false
    @State private var selectedPhotoUrl: String? = nil

    @State private var isSaving = false
    @State private var errorMessage: String?

    init(existingEntry: LogbookEntryDetail? = nil, defaultHelicopterId: Int? = nil, onSave: @escaping () -> Void) {
        self.existingEntry = existingEntry
        self.defaultHelicopterId = defaultHelicopterId
        self.onSave = onSave
    }

    var body: some View {
        NavigationView {
            Form {
                // Basic Info Section
                Section("Event Information") {
                    Picker("Aircraft", selection: $selectedHelicopterId) {
                        ForEach(helicoptersViewModel.helicopters) { heli in
                            Text(heli.tailNumber).tag(heli.id)
                        }
                    }

                    Button(action: { showingCategoryPicker = true }) {
                        HStack {
                            Text("Category")
                                .foregroundColor(.primary)
                            Spacer()
                            if let category = viewModel.categories.first(where: { $0.id == selectedCategoryId }) {
                                Image(systemName: category.icon)
                                    .foregroundColor(Color(hex: category.color))
                                Text(category.name)
                                    .foregroundColor(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Button(action: { showingDateTimePicker = true }) {
                        HStack {
                            Text("Date & Time")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(formatDateTime(eventDate))
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Text("Hours at Event")
                        Spacer()
                        TextField("", text: $hoursAtEvent)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }

                // Description Section
                Section("Description") {
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)

                    TextField("Notes (Optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                // Financial Section
                Section("Financial") {
                    TextField("Cost (Optional)", text: $cost)
                        .keyboardType(.decimalPad)
                }

                // Next Due Section
                Section("Next Due (Optional)") {
                    TextField("Next Due Hours", text: $nextDueHours)
                        .keyboardType(.decimalPad)

                    Toggle("Set Next Due Date", isOn: $includeNextDueDate)

                    if includeNextDueDate {
                        DatePicker("Next Due Date", selection: Binding(
                            get: { nextDueDate ?? Date() },
                            set: { nextDueDate = $0 }
                        ), displayedComponents: .date)
                    }
                }

                // Photos Section
                Section("Photos") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // Show existing attachments
                            ForEach(existingAttachments.filter { $0.fileType?.starts(with: "image/") ?? false }) { attachment in
                                ZStack(alignment: .topTrailing) {
                                    AsyncImage(url: URL(string: "http://192.168.68.6:3000\(attachment.filePath)")) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 100, height: 100)
                                                .clipped()
                                                .cornerRadius(8)
                                                .onTapGesture {
                                                    selectedPhotoUrl = "http://192.168.68.6:3000\(attachment.filePath)"
                                                }
                                        default:
                                            ProgressView()
                                                .frame(width: 100, height: 100)
                                        }
                                    }

                                    Button(action: { deleteAttachment(attachment.id) }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.white)
                                            .background(Circle().fill(Color.red))
                                    }
                                    .offset(x: 8, y: -8)
                                }
                            }

                            // Show newly selected photos
                            ForEach(Array(selectedPhotos.enumerated()), id: \.offset) { index, image in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipped()
                                        .cornerRadius(8)

                                    Button(action: { removePhoto(at: index) }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.white)
                                            .background(Circle().fill(Color.red))
                                    }
                                    .offset(x: 8, y: -8)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    HStack(spacing: 12) {
                        Button(action: { showingCamera = true }) {
                            Label("Take Photo", systemImage: "camera.fill")
                        }

                        Button(action: { showingImagePicker = true }) {
                            Label("Choose Photos", systemImage: "photo.fill")
                        }
                    }
                }

                // Documents Section
                Section("Documents") {
                    // Show existing document attachments
                    ForEach(existingAttachments.filter { !($0.fileType?.starts(with: "image/") ?? false) }) { attachment in
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundColor(.blue)
                            Text(attachment.fileName)
                                .font(.caption)
                            Spacer()
                            Button(action: { deleteAttachment(attachment.id) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    // Show newly selected documents
                    ForEach(Array(selectedDocuments.enumerated()), id: \.offset) { index, url in
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundColor(.blue)
                            Text(url.lastPathComponent)
                                .font(.caption)
                            Spacer()
                            Button(action: { removeDocument(at: index) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    Button(action: { showingDocumentPicker = true }) {
                        Label("Add Documents", systemImage: "doc.badge.plus")
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
            .navigationTitle(existingEntry == nil ? "Add Entry" : "Edit Entry")
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
                            await saveEntry()
                        }
                    }
                    .disabled(isSaving || !isValid)
                }
            }
        }
        .onAppear {
            loadExistingData()
        }
        .sheet(isPresented: $showingCategoryPicker) {
            NavigationView {
                List {
                    ForEach(viewModel.categories) { category in
                        Button(action: {
                            selectedCategoryId = category.id
                            showingCategoryPicker = false
                        }) {
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundColor(Color(hex: category.color))
                                    .frame(width: 30)
                                Text(category.name)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedCategoryId == category.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Select Category")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingCategoryPicker = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingDateTimePicker) {
            NavigationView {
                VStack {
                    DatePicker("Date & Time", selection: $eventDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.graphical)
                        .padding()
                    Spacer()
                }
                .navigationTitle("Select Date & Time")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingDateTimePicker = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingCamera) {
            LogbookCameraView(onImageCaptured: { image in
                selectedPhotos.append(image)
            })
        }
        .sheet(isPresented: $showingImagePicker) {
            LogbookPhotoLibraryPicker(images: $selectedPhotos)
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker { urls in
                selectedDocuments.append(contentsOf: urls)
            }
        }
        .fullScreenCover(item: Binding(
            get: { selectedPhotoUrl.map { PhotoURL(url: $0) } },
            set: { selectedPhotoUrl = $0?.url }
        )) { photoURL in
            FullScreenPhotoView(photoUrl: photoURL.url, onDismiss: {
                selectedPhotoUrl = nil
            })
        }
    }

    struct PhotoURL: Identifiable {
        let id = UUID()
        let url: String
    }

    private var isValid: Bool {
        !description.isEmpty && selectedHelicopterId > 0 && selectedCategoryId > 0
    }

    private func removePhoto(at index: Int) {
        selectedPhotos.remove(at: index)
    }

    private func removeDocument(at index: Int) {
        selectedDocuments.remove(at: index)
    }

    private func deleteAttachment(_ attachmentId: Int) {
        Task {
            do {
                try await APIService.shared.deleteLogbookAttachment(id: attachmentId)
                // Reload attachments
                if let existing = existingEntry {
                    let detail = try await APIService.shared.getLogbookEntry(id: existing.id)
                    existingAttachments = detail.attachments
                }
            } catch {
                errorMessage = "Failed to delete attachment: \(error.localizedDescription)"
            }
        }
    }

    private func loadExistingData() {
        if let existing = existingEntry {
            selectedHelicopterId = existing.helicopterId
            selectedCategoryId = existing.categoryId

            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: existing.eventDate) {
                eventDate = date
            }

            if let hours = existing.hoursAtEvent {
                hoursAtEvent = String(format: "%.1f", hours)
            }

            description = existing.description
            notes = existing.notes ?? ""

            if let existingCost = existing.cost {
                cost = String(format: "%.2f", existingCost)
            }

            if let nextHours = existing.nextDueHours {
                nextDueHours = String(format: "%.1f", nextHours)
            }

            if let nextDate = existing.nextDueDate {
                includeNextDueDate = true
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                if let date = dateFormatter.date(from: nextDate) {
                    self.nextDueDate = date
                }
            }

            // Load existing attachments
            existingAttachments = existing.attachments
        } else {
            // New entry defaults
            // Use default helicopter ID if provided, otherwise use first helicopter
            if let defaultId = defaultHelicopterId,
               let helicopter = helicoptersViewModel.helicopters.first(where: { $0.id == defaultId }) {
                selectedHelicopterId = helicopter.id
                if let currentHours = helicopter.currentHours {
                    hoursAtEvent = String(format: "%.1f", currentHours)
                }
            } else if let firstHeli = helicoptersViewModel.helicopters.first {
                selectedHelicopterId = firstHeli.id
                if let currentHours = firstHeli.currentHours {
                    hoursAtEvent = String(format: "%.1f", currentHours)
                }
            }

            if let firstCategory = viewModel.categories.first {
                selectedCategoryId = firstCategory.id
            }
        }
    }

    private func saveEntry() async {
        errorMessage = nil
        isSaving = true

        let formatter = ISO8601DateFormatter()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let entryCreate = LogbookEntryCreate(
            helicopterId: selectedHelicopterId,
            categoryId: selectedCategoryId,
            eventDate: formatter.string(from: eventDate),
            hoursAtEvent: Double(hoursAtEvent),
            description: description,
            notes: notes.isEmpty ? nil : notes,
            cost: cost.isEmpty ? nil : Double(cost),
            nextDueHours: nextDueHours.isEmpty ? nil : Double(nextDueHours),
            nextDueDate: includeNextDueDate && nextDueDate != nil ? dateFormatter.string(from: nextDueDate!) : nil
        )

        do {
            let savedEntry: LogbookEntry
            if let existing = existingEntry {
                savedEntry = try await APIService.shared.updateLogbookEntry(id: existing.id, entry: entryCreate)
            } else {
                savedEntry = try await APIService.shared.createLogbookEntry(entry: entryCreate)
            }

            // Upload new attachments (for both new and existing entries)
            if !selectedPhotos.isEmpty || !selectedDocuments.isEmpty {
                await uploadAttachments(entryId: savedEntry.id)
            }

            onSave()
            dismiss()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }

        isSaving = false
    }

    private func uploadAttachments(entryId: Int) async {
        // Upload photos
        for (index, image) in selectedPhotos.enumerated() {
            if let data = image.jpegData(compressionQuality: 0.8) {
                do {
                    _ = try await APIService.shared.uploadLogbookAttachment(
                        entryId: entryId,
                        fileData: data,
                        fileName: "photo_\(index + 1).jpg",
                        mimeType: "image/jpeg"
                    )
                } catch {
                    print("Failed to upload photo: \(error)")
                }
            }
        }

        // Upload documents
        for url in selectedDocuments {
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }

                if let data = try? Data(contentsOf: url) {
                    let mimeType = url.mimeType()
                    do {
                        _ = try await APIService.shared.uploadLogbookAttachment(
                            entryId: entryId,
                            fileData: data,
                            fileName: url.lastPathComponent,
                            mimeType: mimeType
                        )
                    } catch {
                        print("Failed to upload document: \(error)")
                    }
                }
            }
        }
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
