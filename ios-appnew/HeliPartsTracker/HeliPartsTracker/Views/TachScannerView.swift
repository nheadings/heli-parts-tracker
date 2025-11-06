import SwiftUI
import UIKit
import Photos

struct TachScannerView: View {
    let helicopterId: Int
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: LogbookViewModel
    @StateObject private var cameraService = CameraService()
    @State private var showingCamera = false
    @State private var showingImagePicker = false
    @State private var capturedImage: UIImage?
    @State private var recognizedHours: Double?
    @State private var manualHours: String = ""
    @State private var ocrConfidence: Double?
    @State private var notes: String = ""
    @State private var isProcessing = false
    @State private var showingManualEntry = false
    @State private var errorMessage: String?
    @State private var showingSaveConfirmation = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let image = capturedImage {
                        // Show captured image and results
                        CapturedImageSection(
                            image: image,
                            recognizedHours: recognizedHours,
                            ocrConfidence: ocrConfidence,
                            onRetake: {
                                capturedImage = nil
                                recognizedHours = nil
                                ocrConfidence = nil
                                manualHours = ""
                                showingManualEntry = false
                            }
                        )

                        // Hours input
                        HoursInputSection(
                            recognizedHours: recognizedHours,
                            manualHours: $manualHours,
                            showingManualEntry: $showingManualEntry
                        )

                        // Notes
                        NotesSection(notes: $notes)

                        // Save button
                        SaveButton(
                            isProcessing: isProcessing,
                            canSave: !manualHours.isEmpty,
                            action: saveHours
                        )
                    } else if showingManualEntry {
                        // Show manual entry form without image
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Enter Hours Manually")
                                .font(.headline)

                            TextField("Hours", text: $manualHours)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.title2)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                        // Notes
                        NotesSection(notes: $notes)

                        // Save button
                        SaveButton(
                            isProcessing: isProcessing,
                            canSave: !manualHours.isEmpty,
                            action: saveHours
                        )
                    } else {
                        // Show camera options
                        CameraOptionsSection(
                            onTakePhoto: {
                                showingCamera = true
                                cameraService.showingCamera = true
                            },
                            onChoosePhoto: {
                                showingImagePicker = true
                            },
                            onManualEntry: {
                                showingManualEntry = true
                            }
                        )
                    }

                    if let error = errorMessage {
                        ErrorBanner(message: error)
                    }
                }
                .padding()
            }
            .navigationTitle("Update Hours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraViewWrapper(
                    cameraService: cameraService,
                    onCapture: processImage,
                    onDismiss: {
                        showingCamera = false
                    }
                )
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $capturedImage, onImagePicked: processImage)
            }
            .alert("Hours Updated", isPresented: $showingSaveConfirmation) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Helicopter hours have been successfully updated.")
            }
        }
    }

    private func processImage(_ image: UIImage) {
        capturedImage = image
        isProcessing = true
        errorMessage = nil

        // Check image quality
        let quality = OCRService.shared.analyzeImageQuality(image: image)
        if !quality.isSuitable {
            errorMessage = quality.reason
            isProcessing = false
            return
        }

        // Perform OCR
        OCRService.shared.recognizeText(from: image) { result in
            DispatchQueue.main.async {
                if let result = result {
                    recognizedHours = result.recognizedHours
                    ocrConfidence = result.confidence
                    manualHours = result.recognizedHours != nil ? String(format: "%.1f", result.recognizedHours!) : ""

                    if result.recognizedHours == nil {
                        errorMessage = "Could not detect hours. Please enter manually."
                        showingManualEntry = true
                    }
                } else {
                    errorMessage = "OCR failed. Please enter hours manually."
                    showingManualEntry = true
                }
                isProcessing = false
            }
        }
    }

    private func saveHours() {
        guard let hours = Double(manualHours), hours > 0 else {
            errorMessage = "Please enter valid hours"
            return
        }

        isProcessing = true
        errorMessage = nil

        Task {
            do {
                // TODO: Upload photo and get URL
                let photoUrl: String? = nil

                try await viewModel.updateHours(
                    helicopterId: helicopterId,
                    hours: hours,
                    photoUrl: photoUrl,
                    ocrConfidence: ocrConfidence,
                    entryMethod: capturedImage != nil ? "ocr" : "manual",
                    notes: notes.isEmpty ? nil : notes
                )

                // Save photo to user's Photos library if they have one
                if let image = capturedImage {
                    saveToPhotosLibrary(image)
                }

                await MainActor.run {
                    isProcessing = false
                    showingSaveConfirmation = true
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "Failed to save hours: \(error.localizedDescription)"
                }
            }
        }
    }

    private func saveToPhotosLibrary(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            }
        }
    }
}

struct CapturedImageSection: View {
    let image: UIImage
    let recognizedHours: Double?
    let ocrConfidence: Double?
    let onRetake: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
                .cornerRadius(12)

            if let hours = recognizedHours, let confidence = ocrConfidence {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Detected: \(String(format: "%.1f", hours)) hours")
                            .fontWeight(.semibold)
                    }

                    Text("Confidence: \(String(format: "%.0f", confidence))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }

            Button(action: onRetake) {
                Label("Retake Photo", systemImage: "camera.rotate")
                    .font(.subheadline)
            }
        }
    }
}

struct HoursInputSection: View {
    let recognizedHours: Double?
    @Binding var manualHours: String
    @Binding var showingManualEntry: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tach Hours")
                .font(.headline)

            TextField("Enter hours", text: $manualHours)
                .keyboardType(.decimalPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.title2)

            if recognizedHours == nil {
                Text("Manual entry required - OCR could not detect hours")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct NotesSection: View {
    @Binding var notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes (Optional)")
                .font(.headline)

            TextEditor(text: $notes)
                .frame(height: 100)
                .padding(4)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct SaveButton: View {
    let isProcessing: Bool
    let canSave: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
                Text(isProcessing ? "Saving..." : "Save Hours")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canSave && !isProcessing ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!canSave || isProcessing)
    }
}

struct CameraOptionsSection: View {
    let onTakePhoto: () -> Void
    let onChoosePhoto: () -> Void
    let onManualEntry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Update Tach Hours")
                .font(.title2)
                .fontWeight(.bold)

            Text("Take a photo of your tach to automatically extract hours, or enter manually")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 12) {
                Button(action: onTakePhoto) {
                    Label("Take Photo", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                Button(action: onChoosePhoto) {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                }

                Button(action: onManualEntry) {
                    Label("Enter Manually", systemImage: "keyboard")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
            }
        }
        .padding()
    }
}

struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.subheadline)
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

struct CameraViewWrapper: View {
    @ObservedObject var cameraService: CameraService
    let onCapture: (UIImage) -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            CameraPreview(session: cameraService.session)
                .edgesIgnoringSafeArea(.all)
                .onAppear {
                    cameraService.setupCamera()
                    cameraService.startSession()
                }
                .onDisappear {
                    cameraService.stopSession()
                }

            VStack {
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                    .padding()

                    Spacer()
                }

                Spacer()

                Button(action: {
                    cameraService.capturePhoto { image in
                        if let image = image {
                            onCapture(image)
                            onDismiss()
                        }
                    }
                }) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 70, height: 70)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 80, height: 80)
                        )
                }
                .padding(.bottom, 40)
            }
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
                parent.onImagePicked(image)
            }
            picker.dismiss(animated: true)
        }
    }
}
