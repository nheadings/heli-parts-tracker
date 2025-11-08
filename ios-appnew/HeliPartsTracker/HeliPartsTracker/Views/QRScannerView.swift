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
    @State private var foundPartWithConflicts: PartWithConflicts?
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
                .onChange(of: detectedTexts) { oldValue, newValue in
                    // Auto-search new detections immediately
                    for detected in newValue {
                        if !searchedTexts.contains(detected.text) &&
                           !currentlySearching.contains(detected.text) {
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
            .sheet(item: $foundPartWithConflicts) { partData in
                NavigationStack {
                    PartDetailView(
                        part: partData.part,
                        conflictWarning: partData.hasConflicts ? partData.conflicts : nil
                    )
                    .environmentObject(partsViewModel)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                foundPartWithConflicts = nil
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
            searchedTexts.insert(normalizedPartNumber)
            return
        }

        // Don't search if we already did or if we're currently searching
        // Use NORMALIZED part number to prevent "P/N C123-1" and "C123-1" from being searched twice
        guard !searchedTexts.contains(normalizedPartNumber) && !currentlySearching.contains(normalizedPartNumber) else {
            return
        }

        // Mark as currently searching (use normalized to prevent duplicates)
        currentlySearching.insert(normalizedPartNumber)

        Task {
            do {
                // Search the database using the normalized part number
                print("🔍 Searching for normalized: '\(normalizedPartNumber)' (original: '\(partNumber)')")
                let response = try await APIService.shared.searchParts(query: normalizedPartNumber, limit: 10)

                await MainActor.run {
                    // Remove from currently searching (use normalized)
                    currentlySearching.remove(normalizedPartNumber)
                    // Add to searched set (use normalized to prevent duplicates)
                    searchedTexts.insert(normalizedPartNumber)

                    // ONLY accept exact matches (case-insensitive) to prevent OCR errors
                    // Do NOT accept partial matches - prevents C121-1 matching when scanning C121-17
                    if let exactMatch = response.parts?.first(where: {
                        $0.partNumber.lowercased() == normalizedPartNumber.lowercased()
                    }) {
                        // SUCCESS! Found exact match
                        print("✅ Exact match found: \(exactMatch.partNumber)")

                        // Check for longer variants (potential OCR omissions)
                        // If scanned "C123-1" but "C123-17", "C123-10" exist, warn user
                        let longerVariants = response.parts?.filter { part in
                            let partNum = part.partNumber.lowercased()
                            let scanned = normalizedPartNumber.lowercased()
                            // Part must start with scanned text AND be longer
                            return partNum.hasPrefix(scanned) && partNum != scanned
                        } ?? []

                        if longerVariants.isEmpty {
                            print("✅ No conflicts - safe to proceed")
                        } else {
                            print("⚠️ WARNING: Longer variants exist: \(longerVariants.map { $0.partNumber }.joined(separator: ", "))")
                        }

                        // Create PartWithConflicts to pass conflict info to detail view
                        playSuccessSound()
                        foundPartWithConflicts = PartWithConflicts(
                            part: exactMatch,
                            conflicts: longerVariants
                        )
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
                    currentlySearching.remove(normalizedPartNumber)
                    searchedTexts.insert(normalizedPartNumber)
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

class TextScannerViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var currentDevice: AVCaptureDevice?
    weak var delegate: TextScannerDelegate?
    var scanRegion: CGRect = CGRect(x: 0.3, y: 0.42, width: 0.4, height: 0.08)
    var isFrozen: Bool = false
    private var lastScanTime: Date?
    private let scanInterval: TimeInterval = 0.1 // Scan every 0.1 seconds (10 times per second)

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
            var candidateTexts: [(text: String, box: CGRect)] = []

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
                        candidateTexts.append((text: text, box: normalizedBox))
                    }
                }
            }

            // Merge adjacent text (e.g., "P/N" + "1234" -> "P/N 1234")
            var mergedTexts: [(text: String, box: CGRect)] = []
            for candidate in candidateTexts {
                // Check if this text is horizontally adjacent to existing text
                var merged = false
                for i in 0..<mergedTexts.count {
                    let existing = mergedTexts[i]

                    // Check if boxes are on same horizontal line and close together
                    let verticalOverlap = min(candidate.box.maxY, existing.box.maxY) - max(candidate.box.minY, existing.box.minY)
                    let horizontalGap = min(abs(candidate.box.minX - existing.box.maxX), abs(existing.box.minX - candidate.box.maxX))

                    if verticalOverlap > 0.01 && horizontalGap < 0.03 {
                        // Merge these texts
                        let combinedText: String
                        let combinedBox: CGRect

                        if candidate.box.minX < existing.box.minX {
                            // Candidate is to the left
                            combinedText = candidate.text + " " + existing.text
                            combinedBox = candidate.box.union(existing.box)
                        } else {
                            // Candidate is to the right
                            combinedText = existing.text + " " + candidate.text
                            combinedBox = existing.box.union(candidate.box)
                        }

                        mergedTexts[i] = (text: combinedText, box: combinedBox)
                        merged = true
                        break
                    }
                }

                if !merged {
                    mergedTexts.append(candidate)
                }
            }

            // Convert merged texts to DetectedText
            for merged in mergedTexts {
                detectedTexts.append(DetectedText(text: merged.text, boundingBox: merged.box))
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
        // Allow very short text if it looks like a prefix (P/N, PN) - will be merged with adjacent text
        let upperText = text.uppercased()
        if upperText == "P/N" || upperText == "PN" || upperText == "P/N:" || upperText == "PN:" {
            return true
        }

        // Must be at least 2 characters for part numbers
        guard text.count >= 2 && text.count <= 25 else { return false }

        // Must contain at least one digit (unless it's a prefix)
        let hasDigit = text.range(of: "[0-9]", options: .regularExpression) != nil
        guard hasDigit else { return false }

        // Should mostly be alphanumeric with common separators
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_./: "))
        guard text.rangeOfCharacter(from: allowedCharacters.inverted) == nil else { return false }

        // Reject if it's purely numeric and very short (likely page numbers, etc.)
        let isOnlyNumbers = text.range(of: "^[0-9]+$", options: .regularExpression) != nil
        if isOnlyNumbers && text.count < 3 {
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
