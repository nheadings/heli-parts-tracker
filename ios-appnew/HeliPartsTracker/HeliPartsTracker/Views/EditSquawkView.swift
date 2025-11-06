import SwiftUI
import PhotosUI

struct EditSquawkView: View {
    @Environment(\.dismiss) private var dismiss
    let squawk: Squawk
    let onSquawkUpdated: () -> Void

    @State private var title: String
    @State private var description: String
    @State private var severity: SquawkSeverity
    @State private var existingPhotoUrls: [String]
    @State private var newPhotos: [UIImage] = []
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(squawk: Squawk, onSquawkUpdated: @escaping () -> Void) {
        self.squawk = squawk
        self.onSquawkUpdated = onSquawkUpdated
        _title = State(initialValue: squawk.title)
        _description = State(initialValue: squawk.description ?? "")
        _severity = State(initialValue: squawk.severity)
        _existingPhotoUrls = State(initialValue: squawk.photos ?? [])
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Squawk Details")) {
                    TextField("Title", text: $title)
                        .autocapitalization(.words)

                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)

                    Picker("Severity", selection: $severity) {
                        ForEach(SquawkSeverity.allCases, id: \.self) { level in
                            HStack {
                                Circle()
                                    .fill(severityColor(level))
                                    .frame(width: 12, height: 12)
                                Text(level.displayName)
                            }
                            .tag(level)
                        }
                    }
                }

                Section(header: Text("Photos")) {
                    // Existing photos
                    if !existingPhotoUrls.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Photos")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(Array(existingPhotoUrls.enumerated()), id: \.offset) { index, url in
                                        ZStack(alignment: .topTrailing) {
                                            AsyncImage(url: URL(string: url)) { phase in
                                                switch phase {
                                                case .empty:
                                                    ProgressView()
                                                        .frame(width: 100, height: 100)
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 100, height: 100)
                                                        .clipped()
                                                        .cornerRadius(8)
                                                case .failure:
                                                    Rectangle()
                                                        .fill(Color.gray.opacity(0.3))
                                                        .frame(width: 100, height: 100)
                                                        .cornerRadius(8)
                                                @unknown default:
                                                    EmptyView()
                                                }
                                            }

                                            Button(action: { removeExistingPhoto(at: index) }) {
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
                        }
                    }

                    // New photos
                    if !newPhotos.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("New Photos")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(Array(newPhotos.enumerated()), id: \.offset) { index, image in
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 100, height: 100)
                                                .clipped()
                                                .cornerRadius(8)

                                            Button(action: { removeNewPhoto(at: index) }) {
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
                        }
                    }

                    HStack(spacing: 12) {
                        Button(action: { showingCamera = true }) {
                            Label("Take Photo", systemImage: "camera.fill")
                        }

                        Button(action: { showingImagePicker = true }) {
                            Label("Choose Photo", systemImage: "photo.fill")
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
            .navigationTitle("Edit Squawk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: saveSquawk) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .sheet(isPresented: $showingCamera) {
                SquawkCameraView(onImageCaptured: { image in
                    newPhotos.append(image)
                })
            }
            .sheet(isPresented: $showingImagePicker) {
                PhotoLibraryPicker(images: $newPhotos)
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func severityColor(_ severity: SquawkSeverity) -> Color {
        switch severity {
        case .routine:
            return .gray
        case .caution:
            return .orange
        case .urgent:
            return .red
        }
    }

    private func removeExistingPhoto(at index: Int) {
        existingPhotoUrls.remove(at: index)
    }

    private func removeNewPhoto(at index: Int) {
        newPhotos.remove(at: index)
    }

    private func saveSquawk() {
        guard !title.isEmpty else {
            errorMessage = "Please enter a title"
            return
        }

        isSaving = true
        errorMessage = nil

        Task {
            do {
                // Upload new photos if any
                var uploadedNewPhotoUrls: [String] = []
                if !newPhotos.isEmpty {
                    uploadedNewPhotoUrls = try await APIService.shared.uploadPhotos(newPhotos)
                }

                // Combine existing and new photo URLs
                let allPhotoUrls = existingPhotoUrls + uploadedNewPhotoUrls

                let squawkUpdate = SquawkUpdate(
                    severity: severity.rawValue,
                    title: title,
                    description: description.isEmpty ? nil : description,
                    photos: allPhotoUrls.isEmpty ? nil : allPhotoUrls
                )

                _ = try await APIService.shared.updateSquawk(
                    id: squawk.id,
                    squawk: squawkUpdate
                )

                await MainActor.run {
                    onSquawkUpdated()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                    isSaving = false
                }
            }
        }
    }
}
