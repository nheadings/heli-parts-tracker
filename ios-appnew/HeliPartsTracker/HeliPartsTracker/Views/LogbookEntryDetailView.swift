import SwiftUI
import Combine
import PhotosUI
import UniformTypeIdentifiers

struct LogbookEntryDetailView: View {
    let entry: LogbookEntry
    let onUpdate: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var helicoptersViewModel: HelicoptersViewModel
    @EnvironmentObject var logbookViewModel: UnifiedLogbookViewModel
    @StateObject private var viewModel = LogbookEntryDetailViewModel()
    @State private var showingEdit = false
    @State private var showingDeleteAlert = false
    @State private var showingCamera = false
    @State private var showingImagePicker = false
    @State private var showingDocumentPicker = false
    @State private var selectedPhotoUrl: String? = nil

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else if let entryDetail = viewModel.entryDetail {
                        // Header
                        header(entryDetail)

                        Divider()

                        // Details
                        details(entryDetail)

                        Divider()

                        // Attachments
                        attachments(entryDetail)
                    } else if let error = viewModel.errorMessage {
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("Entry Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingEdit = true }) {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive, action: { showingDeleteAlert = true }) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .task {
            await viewModel.loadEntry(id: entry.id)
        }
        .sheet(isPresented: $showingEdit) {
            if let entryDetail = viewModel.entryDetail {
                AddLogbookEntryView(existingEntry: entryDetail, defaultHelicopterId: nil, onSave: {
                    Task {
                        await viewModel.loadEntry(id: entry.id)
                        onUpdate()
                    }
                })
                .environmentObject(helicoptersViewModel)
                .environmentObject(logbookViewModel)
            }
        }
        .alert("Delete Entry?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await deleteEntry()
                }
            }
        } message: {
            Text("This will permanently delete this logbook entry and all its attachments. This action cannot be undone.")
        }
        .sheet(isPresented: $showingCamera) {
            LogbookCameraView(onImageCaptured: { image in
                Task {
                    if let data = image.jpegData(compressionQuality: 0.8) {
                        await uploadAttachment(data: data, fileName: "photo.jpg", mimeType: "image/jpeg")
                    }
                }
            })
        }
        .sheet(isPresented: $showingImagePicker) {
            LogbookPhotoLibraryPickerForDetail(entryId: entry.id, onUpdate: {
                Task {
                    await viewModel.loadEntry(id: entry.id)
                    onUpdate()
                }
            })
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker { urls in
                Task {
                    await uploadDocuments(urls)
                }
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

    private func header(_ entryDetail: LogbookEntryDetail) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: entryDetail.categoryIcon)
                .font(.system(size: 50))
                .foregroundColor(Color(hex: entryDetail.categoryColor))

            VStack(alignment: .leading, spacing: 4) {
                Text(entryDetail.categoryName)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(entryDetail.tailNumber)
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text(formatDateTime(entryDetail.eventDate))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func details(_ entryDetail: LogbookEntryDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Description
            DetailRow(label: "Description", value: entryDetail.description)

            // Hours
            if let hours = entryDetail.hoursAtEvent {
                DetailRow(label: "Hours at Event", value: String(format: "%.1f", hours))
            }

            // Cost
            if let cost = entryDetail.cost {
                DetailRow(label: "Cost", value: String(format: "$%.2f", cost))
            }

            // Next Due
            if let nextDue = entryDetail.nextDueHours {
                DetailRow(label: "Next Due Hours", value: String(format: "%.1f", nextDue))
            }

            if let nextDate = entryDetail.nextDueDate {
                DetailRow(label: "Next Due Date", value: nextDate)
            }

            // Notes
            if let notes = entryDetail.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Text(notes)
                        .font(.body)
                }
            }

            // Performed By
            if let performer = entryDetail.performedByName ?? entryDetail.performedByUsername {
                DetailRow(label: "Performed By", value: performer)
            }
        }
    }

    private func attachments(_ entryDetail: LogbookEntryDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Attachments")
                    .font(.headline)
                Spacer()
                Menu {
                    Button(action: { showingCamera = true }) {
                        Label("Take Photo", systemImage: "camera")
                    }
                    Button(action: { showingImagePicker = true }) {
                        Label("Choose Photos", systemImage: "photo")
                    }
                    Button(action: { showingDocumentPicker = true }) {
                        Label("Add Document", systemImage: "doc")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
            }

            if entryDetail.attachments.isEmpty {
                Text("No attachments")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                // Separate photos and documents
                let photos = entryDetail.attachments.filter { $0.fileType?.starts(with: "image/") ?? false }
                let documents = entryDetail.attachments.filter { !($0.fileType?.starts(with: "image/") ?? false) }

                // Display photos in horizontal scroll
                if !photos.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Photos")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(photos) { attachment in
                                    AsyncImage(url: URL(string: "http://192.168.68.6:3000\(attachment.filePath)")) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView()
                                                .frame(width: 150, height: 150)
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 150, height: 150)
                                                .clipped()
                                                .cornerRadius(8)
                                                .onTapGesture {
                                                    selectedPhotoUrl = "http://192.168.68.6:3000\(attachment.filePath)"
                                                }
                                        case .failure:
                                            VStack {
                                                Image(systemName: "photo")
                                                    .font(.largeTitle)
                                                Text("Failed to load")
                                                    .font(.caption)
                                            }
                                            .frame(width: 150, height: 150)
                                            .background(Color.gray.opacity(0.2))
                                            .cornerRadius(8)
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // Display documents as list
                if !documents.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Documents")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        ForEach(documents) { attachment in
                            AttachmentRow(attachment: attachment, onDelete: {
                                Task {
                                    await deleteAttachment(attachment.id)
                                }
                            })
                        }
                    }
                }
            }
        }
    }

    private func deleteEntry() async {
        do {
            try await APIService.shared.deleteLogbookEntry(id: entry.id)
            onUpdate()
            dismiss()
        } catch {
            viewModel.errorMessage = "Failed to delete: \(error.localizedDescription)"
        }
    }

    private func deleteAttachment(_ attachmentId: Int) async {
        do {
            try await APIService.shared.deleteLogbookAttachment(id: attachmentId)
            await viewModel.loadEntry(id: entry.id)
            onUpdate()
        } catch {
            viewModel.errorMessage = "Failed to delete attachment: \(error.localizedDescription)"
        }
    }

    private func uploadDocuments(_ urls: [URL]) async {
        for url in urls {
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }

                if let data = try? Data(contentsOf: url) {
                    let mimeType = url.mimeType()
                    await uploadAttachment(data: data, fileName: url.lastPathComponent, mimeType: mimeType)
                }
            }
        }
    }

    private func uploadAttachment(data: Data, fileName: String, mimeType: String) async {
        do {
            _ = try await APIService.shared.uploadLogbookAttachment(entryId: entry.id, fileData: data, fileName: fileName, mimeType: mimeType)
            await viewModel.loadEntry(id: entry.id)
            onUpdate()
        } catch {
            viewModel.errorMessage = "Failed to upload: \(error.localizedDescription)"
        }
    }

    private func formatDateTime(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .long
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }
}

struct AttachmentRow: View {
    let attachment: LogbookAttachment
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Image(systemName: iconForFileType(attachment.fileType))
                .foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.fileName)
                    .font(.subheadline)
                if let size = attachment.fileSize {
                    Text(formatFileSize(size))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private func iconForFileType(_ type: String?) -> String {
        guard let type = type else { return "doc" }
        if type.starts(with: "image/") {
            return "photo"
        } else if type.contains("pdf") {
            return "doc.text"
        } else {
            return "doc"
        }
    }

    private func formatFileSize(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024
        if kb < 1024 {
            return String(format: "%.1f KB", kb)
        } else {
            return String(format: "%.1f MB", kb / 1024)
        }
    }
}

// MARK: - ViewModel

@MainActor
class LogbookEntryDetailViewModel: ObservableObject {
    @Published var entryDetail: LogbookEntryDetail?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadEntry(id: Int) async {
        isLoading = true
        errorMessage = nil

        do {
            entryDetail = try await APIService.shared.getLogbookEntry(id: id)
        } catch {
            errorMessage = "Failed to load entry: \(error.localizedDescription)"
        }

        isLoading = false
    }
}

// MARK: - Photo Library Picker for Detail View

struct LogbookPhotoLibraryPickerForDetail: View {
    let entryId: Int
    let onUpdate: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedImages: [UIImage] = []
    @State private var isUploading = false

    var body: some View {
        NavigationView {
            VStack {
                if isUploading {
                    ProgressView("Uploading photos...")
                        .padding()
                } else {
                    LogbookPhotoLibraryPicker(images: $selectedImages)
                }
            }
            .navigationTitle("Select Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        Task {
                            await uploadPhotos()
                        }
                    }
                    .disabled(selectedImages.isEmpty || isUploading)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func uploadPhotos() async {
        isUploading = true

        for (index, image) in selectedImages.enumerated() {
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

        isUploading = false
        onUpdate()
        dismiss()
    }
}
