import SwiftUI
import PhotosUI

struct AddSquawkView: View {
    @Environment(\.dismiss) private var dismiss
    let helicopterId: Int
    let onSquawkAdded: () -> Void

    @State private var title = ""
    @State private var description = ""
    @State private var severity: SquawkSeverity = .routine
    @State private var photos: [UIImage] = []
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var isSaving = false
    @State private var errorMessage: String?

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
                    if !photos.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(photos.enumerated()), id: \.offset) { index, image in
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
            .navigationTitle("Add Squawk")
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
                    photos.append(image)
                })
            }
            .sheet(isPresented: $showingImagePicker) {
                PhotoLibraryPicker(images: $photos)
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

    private func removePhoto(at index: Int) {
        photos.remove(at: index)
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
                // TODO: Upload photos to server and get URLs
                let photoUrls: [String] = []  // Placeholder

                let squawk = SquawkCreate(
                    severity: severity.rawValue,
                    title: title,
                    description: description.isEmpty ? nil : description,
                    photos: photoUrls.isEmpty ? nil : photoUrls
                )

                _ = try await APIService.shared.createSquawk(
                    helicopterId: helicopterId,
                    squawk: squawk
                )

                onSquawkAdded()
                dismiss()
            } catch {
                errorMessage = "Failed to save: \(error.localizedDescription)"
                isSaving = false
            }
        }
    }
}

// MARK: - Photo Library Picker

struct PhotoLibraryPicker: UIViewControllerRepresentable {
    @Binding var images: [UIImage]
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 5 - images.count
        config.filter = .images

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoLibraryPicker

        init(_ parent: PhotoLibraryPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()

            for result in results {
                result.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                    if let image = object as? UIImage {
                        DispatchQueue.main.async {
                            self.parent.images.append(image)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Squawk Camera View

import UIKit

struct SquawkCameraView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: SquawkCameraView

        init(_ parent: SquawkCameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
