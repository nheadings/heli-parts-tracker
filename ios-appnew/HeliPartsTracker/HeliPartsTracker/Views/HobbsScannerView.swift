import SwiftUI
import Vision

struct HobbsScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let helicopterId: Int
    let currentHours: Double
    let onHobbsScanned: (Double) -> Void
    let scanOnly: Bool  // If true, only scan and return value, don't update DB
    let autoOpenCamera: Bool  // If true, automatically open camera on appear

    @State private var showingCamera = false
    @State private var capturedImage: UIImage?
    @State private var hobbsHours: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var warningMessage: String?
    @State private var showingWarningConfirmation = false
    @State private var pendingHours: Double?

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

                // Current Hobbs Display
                VStack(spacing: 8) {
                    Text("Current Hobbs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f hours", currentHours))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)

                // Manual entry
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter new Hobbs reading")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("New Hobbs Hours", text: $hobbsHours)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.title2)
                }
                .padding(.horizontal)

                if let error = errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                }

                if let warning = warningMessage {
                    Text(warning)
                        .font(.callout)
                        .foregroundColor(.orange)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
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
            .alert("Confirm Large Hour Increase", isPresented: $showingWarningConfirmation) {
                Button("Cancel", role: .cancel) {
                    pendingHours = nil
                    warningMessage = nil
                }
                Button("Save Anyway") {
                    if let hours = pendingHours {
                        performSave(hours: hours)
                    }
                }
            } message: {
                if let hours = pendingHours {
                    let difference = hours - currentHours
                    Text("You're about to add \(String(format: "%.1f", difference)) hours, which is unusually high for a single flight. Are you sure this is correct?")
                }
            }
            .onAppear {
                if autoOpenCamera {
                    showingCamera = true
                }
            }
            .onChange(of: capturedImage) { image in
                if let image = image {
                    performOCR(on: image)
                }
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
            warningMessage = nil
            return
        }

        // Validation: Cannot be less than current Hobbs
        if hours < currentHours {
            errorMessage = "New Hobbs reading (\(String(format: "%.1f", hours))) cannot be less than current Hobbs (\(String(format: "%.1f", currentHours)))"
            warningMessage = nil
            return
        }

        // Warning: More than 20 hours difference
        let difference = hours - currentHours
        if difference > 20 {
            pendingHours = hours
            warningMessage = "Large difference detected: \(String(format: "%.1f", difference)) hours. This is unusual for a single flight."
            showingWarningConfirmation = true
            return
        }

        // If validation passes, proceed with save
        performSave(hours: hours)
    }

    private func performSave(hours: Double) {
        // If scanOnly mode, just return the value without saving to DB
        if scanOnly {
            onHobbsScanned(hours)
            dismiss()
            return
        }

        isSaving = true
        errorMessage = nil
        warningMessage = nil

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

                // Create a flight record
                let tachTime = hours - currentHours
                if tachTime > 0 {
                    let now = ISO8601DateFormatter().string(from: Date())

                    // Calculate departure time based on tach time (assuming tach time = flight time)
                    let departureDate = Date().addingTimeInterval(-tachTime * 3600)
                    let departureTime = ISO8601DateFormatter().string(from: departureDate)

                    let flightCreate = FlightCreate(
                        hobbsStart: currentHours,
                        hobbsEnd: hours,
                        flightTime: tachTime, // Same as tach for quick Hobbs entry
                        tachTime: tachTime,
                        departureTime: departureTime,
                        arrivalTime: now,
                        hobbsPhotoUrl: nil,
                        ocrConfidence: capturedImage != nil ? 0.0 : nil,
                        notes: nil
                    )

                    _ = try await APIService.shared.createFlight(helicopterId: helicopterId, flight: flightCreate)
                }

                onHobbsScanned(hours)
                dismiss()
            } catch {
                errorMessage = "Failed to save: \(error.localizedDescription)"
                isSaving = false
            }
        }
    }

    private func performOCR(on image: UIImage) {
        guard let cgImage = image.cgImage else { return }

        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }

            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: " ")

            // Extract hours from recognized text
            if let hours = extractHoursFromOCR(recognizedText) {
                DispatchQueue.main.async {
                    hobbsHours = String(format: "%.1f", hours)
                }
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }

    private func extractHoursFromOCR(_ text: String) -> Double? {
        // Look for numbers with optional decimal point (e.g., 1234.5, 1234, 123.45)
        // Prioritize numbers that look like Hobbs readings (typically 3-5 digits)
        let pattern = "\\d{3,5}(?:\\.\\d{1,2})?"

        if let range = text.range(of: pattern, options: .regularExpression) {
            let numberString = String(text[range])
            return Double(numberString)
        }

        // Fallback to any decimal number
        let fallbackPattern = "\\d+\\.\\d+"
        if let range = text.range(of: fallbackPattern, options: .regularExpression) {
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
