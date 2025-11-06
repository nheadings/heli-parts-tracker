import SwiftUI

struct HobbsScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let helicopterId: Int
    let onHobbsScanned: (Double) -> Void

    @State private var showingCamera = false
    @State private var capturedImage: UIImage?
    @State private var hobbsHours: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let image = capturedImage {
                    // Show captured image
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .cornerRadius(12)

                    Button(action: { capturedImage = nil }) {
                        Label("Retake Photo", systemImage: "camera.fill")
                    }
                } else {
                    // Camera button
                    VStack(spacing: 16) {
                        Image(systemName: "camera.metering.matrix")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)

                        Text("Scan Hobbs Meter")
                            .font(.title3)
                            .fontWeight(.medium)

                        Text("Take a photo of the Hobbs meter to automatically read the hours")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button(action: { showingCamera = true }) {
                            Label("Open Camera", systemImage: "camera.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
                }

                // Manual entry
                VStack(alignment: .leading, spacing: 8) {
                    Text("Or enter hours manually")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("Hobbs Hours", text: $hobbsHours)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.title2)
                }
                .padding(.horizontal)

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                Spacer()

                // Save button
                Button(action: saveHobbsReading) {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("Save Reading")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(canSave ? Color.green : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(!canSave || isSaving)
                .padding(.horizontal)
            }
            .padding(.vertical)
            .navigationTitle("Hobbs Reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                SimpleCameraView(capturedImage: $capturedImage)
            }
        }
    }

    private var canSave: Bool {
        guard let hours = Double(hobbsHours), hours > 0 else {
            return false
        }
        return true
    }

    private func saveHobbsReading() {
        guard let hours = Double(hobbsHours) else {
            errorMessage = "Please enter valid hours"
            return
        }

        isSaving = true
        errorMessage = nil

        Task {
            do {
                // Create hours entry
                let hoursCreate = HelicopterHoursCreate(
                    hours: hours,
                    photoUrl: nil,  // TODO: Upload photo to server
                    ocrConfidence: nil,
                    entryMethod: capturedImage != nil ? "ocr" : "manual",
                    notes: nil
                )

                _ = try await APIService.shared.updateHelicopterHours(
                    helicopterId: helicopterId,
                    hours: hoursCreate
                )

                onHobbsScanned(hours)
                dismiss()
            } catch {
                errorMessage = "Failed to save: \(error.localizedDescription)"
                isSaving = false
            }
        }
    }

    private func extractHoursFromOCR(_ text: String) -> Double? {
        // Simple extraction - look for numbers that could be Hobbs hours
        let pattern = "\\d+\\.?\\d*"
        if let range = text.range(of: pattern, options: .regularExpression) {
            let numberString = String(text[range])
            return Double(numberString)
        }
        return nil
    }
}

// MARK: - Simple Camera View

import UIKit

struct SimpleCameraView: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
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
        let parent: SimpleCameraView

        init(_ parent: SimpleCameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.capturedImage = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
