import SwiftUI
import AVFoundation
import Vision
import AudioToolbox
import UIKit

struct DetectedText: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let boundingBox: CGRect

    static func == (lhs: DetectedText, rhs: DetectedText) -> Bool {
        return lhs.text == rhs.text && lhs.boundingBox == rhs.boundingBox
    }
}

struct ScanOverlayView: View {
    let scanRegion: CGRect

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dimmed background
                Color.black.opacity(0.5)

                // Clear cutout for scan region
                Rectangle()
                    .frame(
                        width: scanRegion.width * geometry.size.width,
                        height: scanRegion.height * geometry.size.height
                    )
                    .position(
                        x: (scanRegion.minX + scanRegion.width / 2) * geometry.size.width,
                        y: (scanRegion.minY + scanRegion.height / 2) * geometry.size.height
                    )
                    .blendMode(.destinationOut)

                // Simple border around scan region
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.green, lineWidth: 3)
                    .frame(
                        width: scanRegion.width * geometry.size.width,
                        height: scanRegion.height * geometry.size.height
                    )
                    .position(
                        x: (scanRegion.minX + scanRegion.width / 2) * geometry.size.width,
                        y: (scanRegion.minY + scanRegion.height / 2) * geometry.size.height
                    )
            }
            .compositingGroup()
        }
        .allowsHitTesting(false)
    }
}

struct QRScannerView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var partsViewModel: PartsViewModel
    @State private var detectedTexts: [DetectedText] = []
    @State private var searchedTexts: Set<String> = [] // Track what we've already searched
    @State private var currentlySearching: Set<String> = [] // Track ongoing searches
    @State private var foundPart: Part?
    @State private var isFrozen = false
    @State private var zoomFactor: CGFloat = 1.0
    @State private var lastSuccessfulScan: Date?

    // Define scan region (small, centered rectangle)
    let scanRegion = CGRect(x: 0.3, y: 0.42, width: 0.4, height: 0.08)

    var body: some View {
        NavigationView {
            ZStack {
                TextScannerViewRepresentable(detectedTexts: $detectedTexts, scanRegion: scanRegion, isFrozen: $isFrozen, zoomFactor: $zoomFactor)
                    .edgesIgnoringSafeArea(.all)

                // Dimmed overlay with cutout
                GeometryReader { geometry in
                    ScanOverlayView(scanRegion: scanRegion)
                }

                // Draw detected text in scan region
                GeometryReader { geometry in
                    ForEach(detectedTexts) { detected in
                        let box = detected.boundingBox
                        let centerX = box.midX * geometry.size.width
                        let centerY = box.midY * geometry.size.height
                        let isSearching = currentlySearching.contains(detected.text)
                        let wasSearched = searchedTexts.contains(detected.text)

                        VStack(spacing: 0) {
                            HStack(spacing: 4) {
                                Text(detected.text)
                                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                                if isSearching {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .tint(.white)
                                } else if wasSearched {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.red.opacity(0.8))
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(isSearching ? Color.blue.opacity(0.9) :
                                       wasSearched ? Color.gray.opacity(0.7) : Color.green.opacity(0.9))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                        }
                        .position(x: centerX, y: centerY - 20)
                    }
                }
                .onChange(of: detectedTexts) { newTexts in
                    // Auto-search new detections
                    for detected in newTexts {
                        if !searchedTexts.contains(detected.text) && !currentlySearching.contains(detected.text) {
                            searchForPart(detected.text)
                        }
                    }
                }

                VStack {
                    Spacer()

                    if !currentlySearching.isEmpty {
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .tint(.white)
                                Text("Searching...")
                                    .font(.headline)
                            }
                            Text("\(searchedTexts.count) checked, \(currentlySearching.count) searching")
                                .font(.caption)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.bottom, 20)
                    } else if !detectedTexts.isEmpty {
                        VStack(spacing: 4) {
                            Text("Scanning...")
                                .font(.headline)
                            Text("\(detectedTexts.count) detected")
                                .font(.caption)
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.bottom, 20)
                    }

                    // Zoom control
                    HStack(spacing: 20) {
                        Button(action: { adjustZoom(by: -0.5) }) {
                            Image(systemName: "minus.magnifyingglass")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }

                        Text(String(format: "%.1fx", zoomFactor))
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)

                        Button(action: { adjustZoom(by: 0.5) }) {
                            Image(systemName: "plus.magnifyingglass")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.bottom, 10)

                    // Control buttons
                    HStack(spacing: 20) {
                        // Red X button to restart
                        if isFrozen {
                            Button(action: restartScan) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.red)
                            }
                        }

                        // Shutter button to freeze/unfreeze
                        Button(action: toggleFreeze) {
                            Image(systemName: isFrozen ? "play.circle.fill" : "camera.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $foundPart) { part in
                NavigationView {
                    PartDetailView(part: part)
                        .environmentObject(partsViewModel)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    foundPart = nil
                                    // Close the scanner when part detail is dismissed
                                    dismiss()
                                }
                            }
                        }
                }
            }
        }
    }

    private func toggleFreeze() {
        isFrozen.toggle()
    }

    private func restartScan() {
        isFrozen = false
        detectedTexts = []
        searchedTexts.removeAll()
        currentlySearching.removeAll()
    }

    private func adjustZoom(by delta: CGFloat) {
        let newZoom = zoomFactor + delta
        zoomFactor = max(1.0, min(newZoom, 10.0)) // Clamp between 1x and 10x
    }

    private func playSuccessSound() {
        // Play happy beep beep sound
        AudioServicesPlaySystemSound(1054) // Beep beep

        // Vibrate for haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func normalizePartNumber(_ partNumber: String) -> String {
        var normalized = partNumber.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove common prefixes
        let prefixes = ["P/N", "PN", "P/N:", "PN:"]
        for prefix in prefixes {
            if normalized.uppercased().hasPrefix(prefix) {
                normalized = String(normalized.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: ":- "))
                break
            }
        }

        return normalized
    }

    private func searchForPart(_ partNumber: String) {
        // Normalize the part number (strip P/N prefix, trim whitespace)
        let normalizedPartNumber = normalizePartNumber(partNumber)

        // Skip if too short after normalization
        guard normalizedPartNumber.count >= 3 else {
            searchedTexts.insert(partNumber)
            return
        }

        // Don't search if we already did or if we're currently searching
        guard !searchedTexts.contains(partNumber) && !currentlySearching.contains(partNumber) else {
            return
        }

        // Mark as currently searching
        currentlySearching.insert(partNumber)

        Task {
            do {
                // Search the database using the normalized part number
                print("🔍 Searching for normalized: '\(normalizedPartNumber)' (original: '\(partNumber)')")
                let response = try await APIService.shared.searchParts(query: normalizedPartNumber, limit: 10)

                await MainActor.run {
                    // Remove from currently searching
                    currentlySearching.remove(partNumber)
                    // Add to searched set
                    searchedTexts.insert(partNumber)

                    // ONLY accept exact matches (case-insensitive) to prevent OCR errors
                    // Do NOT accept partial matches - prevents C121-1 matching when scanning C121-17
                    if let part = response.parts?.first(where: {
                        $0.partNumber.lowercased() == normalizedPartNumber.lowercased()
                    }) {
                        // SUCCESS! Found exact match
                        print("✅ Exact match found: \(part.partNumber)")
                        playSuccessSound()
                        foundPart = part
                        // Stop scanning but keep scanner open
                        isFrozen = true
                    } else {
                        // No exact match - log for debugging
                        if let parts = response.parts, !parts.isEmpty {
                            print("⚠️ No exact match. Found similar: \(parts.map { $0.partNumber }.joined(separator: ", "))")
                        } else {
                            print("❌ No results for '\(normalizedPartNumber)'")
                        }
                    }
                    // If no exact match, just mark as searched and continue scanning
                }
            } catch {
                print("Search error for '\(partNumber)': \(error)")
                await MainActor.run {
                    currentlySearching.remove(partNumber)
                    searchedTexts.insert(partNumber)
                }
            }
        }
    }

}

struct TextScannerViewRepresentable: UIViewControllerRepresentable {
    @Binding var detectedTexts: [DetectedText]
    let scanRegion: CGRect
    @Binding var isFrozen: Bool
    @Binding var zoomFactor: CGFloat

    func makeUIViewController(context: Context) -> TextScannerViewController {
        let controller = TextScannerViewController()
        controller.delegate = context.coordinator
        controller.scanRegion = scanRegion
        return controller
    }

    func updateUIViewController(_ uiViewController: TextScannerViewController, context: Context) {
        uiViewController.isFrozen = isFrozen
        uiViewController.setZoom(zoomFactor)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, TextScannerDelegate {
        var parent: TextScannerViewRepresentable

        init(_ parent: TextScannerViewRepresentable) {
            self.parent = parent
        }

        func didDetectTexts(_ texts: [DetectedText]) {
            parent.detectedTexts = texts
        }
    }
}

protocol TextScannerDelegate: AnyObject {
    func didDetectTexts(_ texts: [DetectedText])
}

struct FilteredWordsData: Codable {
    let commonWords: [String]
}

class TextScannerViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var currentDevice: AVCaptureDevice?
    weak var delegate: TextScannerDelegate?
    var scanRegion: CGRect = CGRect(x: 0.3, y: 0.42, width: 0.4, height: 0.08)
    var isFrozen: Bool = false
    private var lastScanTime: Date?
    private let scanInterval: TimeInterval = 0.5 // Scan every 0.5 seconds

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.black
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo

        // Use wide angle camera (default) for best flexibility with zoom
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("❌ No camera found")
            return
        }

        currentDevice = device

        // Configure camera
        do {
            try device.lockForConfiguration()

            // Enable auto focus
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }

            // Enable auto exposure
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }

            device.unlockForConfiguration()
            print("✅ Camera configured with zoom support (min: \(device.minAvailableVideoZoomFactor), max: \(device.maxAvailableVideoZoomFactor))")
        } catch {
            print("⚠️ Could not configure camera: \(error)")
        }

        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: device)
        } catch {
            print("❌ Failed to create video input: \(error)")
            return
        }

        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            failed()
            return
        }

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))

        if (captureSession.canAddOutput(videoOutput)) {
            captureSession.addOutput(videoOutput)
        } else {
            failed()
            return
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }

    func failed() {
        let ac = UIAlertController(title: "Scanning not supported", message: "Your device does not support scanning. Please use a device with a camera.", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
        captureSession = nil
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if (captureSession?.isRunning == false) {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if (captureSession?.isRunning == true) {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.stopRunning()
            }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Don't scan if frozen
        if isFrozen {
            return
        }

        // Throttle scanning to avoid too many requests
        if let lastTime = lastScanTime, Date().timeIntervalSince(lastTime) < scanInterval {
            return
        }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self,
                  let observations = request.results as? [VNRecognizedTextObservation],
                  let previewLayer = self.previewLayer else { return }

            var detectedTexts: [DetectedText] = []

            // Collect all text that matches part number pattern
            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else { continue }
                let text = topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)

                // Filter for part-number-like text (e.g., "C706-1", "AB123", etc.)
                if self.looksLikePartNumber(text) {
                    // Vision gives us normalized coordinates (0-1) with bottom-left origin
                    let visionBox = observation.boundingBox

                    // Convert Vision coordinates to preview layer coordinates
                    let layerBox = previewLayer.layerRectConverted(fromMetadataOutputRect: visionBox)

                    // Normalize to 0-1 range based on preview layer size
                    let normalizedBox = CGRect(
                        x: layerBox.origin.x / previewLayer.bounds.width,
                        y: layerBox.origin.y / previewLayer.bounds.height,
                        width: layerBox.width / previewLayer.bounds.width,
                        height: layerBox.height / previewLayer.bounds.height
                    )

                    // Only include text within the scan region
                    if self.scanRegion.intersects(normalizedBox) {
                        // Check for collision with existing detected texts
                        let hasCollision = detectedTexts.contains { existing in
                            existing.boundingBox.intersects(normalizedBox)
                        }

                        // Only add if no collision with existing text
                        if !hasCollision {
                            detectedTexts.append(DetectedText(text: text, boundingBox: normalizedBox))
                        }
                    }
                }
            }

            // Update UI with all detected text (or clear if none found)
            DispatchQueue.main.async {
                self.delegate?.didDetectTexts(detectedTexts)
                self.lastScanTime = Date()
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }

    private func looksLikePartNumber(_ text: String) -> Bool {
        // Must be 3-20 characters
        guard text.count >= 3 && text.count <= 20 else { return false }

        // Must contain at least one digit
        let hasDigit = text.range(of: "[0-9]", options: .regularExpression) != nil
        guard hasDigit else { return false }

        // Must contain at least one letter OR be mostly numbers with separators
        let hasLetter = text.range(of: "[A-Za-z]", options: .regularExpression) != nil

        // Should mostly be alphanumeric with common separators
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        guard text.rangeOfCharacter(from: allowedCharacters.inverted) == nil else { return false }

        // Reject if it's purely numeric (likely a serial number or other info)
        let isOnlyNumbers = text.range(of: "^[0-9]+$", options: .regularExpression) != nil
        if isOnlyNumbers && text.count < 5 {
            return false
        }

        return true
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    func setZoom(_ factor: CGFloat) {
        guard let device = currentDevice else { return }

        do {
            try device.lockForConfiguration()

            // Clamp zoom factor to device capabilities
            let clampedFactor = min(max(factor, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
            device.videoZoomFactor = clampedFactor

            device.unlockForConfiguration()
        } catch {
            print("⚠️ Could not set zoom: \(error)")
        }
    }
}
