import SwiftUI
import AVFoundation
import Vision

struct DetectedText: Identifiable {
    let id = UUID()
    let text: String
    let boundingBox: CGRect
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

                // Border around scan region
                RoundedRectangle(cornerRadius: 12)
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
    @State private var selectedText: String?
    @State private var foundPart: Part?
    @State private var showingNotFound = false
    @State private var isFrozen = false
    @State private var notFoundText: String = ""
    @State private var showingAddPart = false

    // Define scan region (center rectangle with 16:9 aspect ratio)
    // For 16:9 on iPhone screen, width must be ~3.85x height in normalized coords
    let scanRegion = CGRect(x: 0.275, y: 0.4, width: 0.45, height: 0.117)

    var body: some View {
        NavigationView {
            ZStack {
                TextScannerViewRepresentable(detectedTexts: $detectedTexts, scanRegion: scanRegion, isFrozen: $isFrozen)
                    .edgesIgnoringSafeArea(.all)

                // Dimmed overlay with cutout
                GeometryReader { geometry in
                    ScanOverlayView(scanRegion: scanRegion)
                }

                // Draw bounding boxes over detected text
                GeometryReader { geometry in
                    ForEach(detectedTexts) { detected in
                        let box = detected.boundingBox
                        let width = box.width * geometry.size.width
                        let height = box.height * geometry.size.height
                        let centerX = box.midX * geometry.size.width
                        let centerY = box.midY * geometry.size.height

                        Button(action: {
                            selectedText = detected.text
                            searchForPart(detected.text)
                        }) {
                            VStack(spacing: 2) {
                                Text(detected.text)
                                    .font(.system(size: 24, weight: .bold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.green.opacity(0.9))
                                    .foregroundColor(.white)
                                    .cornerRadius(4)

                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.green, lineWidth: 3)
                                    .frame(width: width, height: height)
                            }
                        }
                        .position(x: centerX, y: centerY)
                    }
                }

                VStack {
                    Spacer()

                    if let text = selectedText {
                        VStack(spacing: 8) {
                            Text("Selected: \(text)")
                                .font(.headline)
                            Text("Searching...")
                                .font(.subheadline)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.bottom, 20)
                    } else if !isFrozen {
                        VStack(spacing: 4) {
                            Text("Tap text to search")
                                .font(.headline)
                            Text("\(detectedTexts.count) part numbers found")
                                .font(.caption)
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.bottom, 20)
                    } else {
                        VStack(spacing: 4) {
                            Text("Frozen - Tap text to search")
                                .font(.headline)
                            Text("\(detectedTexts.count) part numbers visible")
                                .font(.caption)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.bottom, 20)
                    }

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
                }
            }
            .alert("Part Not Found", isPresented: $showingNotFound) {
                Button("Add New Part") {
                    showingAddPart = true
                    selectedText = nil
                }
                Button("Add to Filter List") {
                    addToFilteredWords(notFoundText)
                    selectedText = nil
                }
                Button("Cancel", role: .cancel) {
                    selectedText = nil
                }
            } message: {
                Text("No part found with number: \(notFoundText)\n\nWhat would you like to do?")
            }
            .sheet(isPresented: $showingAddPart) {
                AddPartView(defaultPartNumber: notFoundText)
                    .environmentObject(partsViewModel)
            }
        }
    }

    private func toggleFreeze() {
        isFrozen.toggle()
    }

    private func restartScan() {
        isFrozen = false
        detectedTexts = []
        selectedText = nil
    }

    private func searchForPart(_ partNumber: String) {
        // Search for exact match first
        if let part = partsViewModel.parts.first(where: { $0.partNumber.lowercased() == partNumber.lowercased() }) {
            foundPart = part
            selectedText = nil
            detectedTexts = []
            isFrozen = false
        } else {
            // Try partial match
            if let part = partsViewModel.parts.first(where: { $0.partNumber.lowercased().contains(partNumber.lowercased()) }) {
                foundPart = part
                selectedText = nil
                detectedTexts = []
                isFrozen = false
            } else {
                notFoundText = partNumber
                showingNotFound = true
            }
        }
    }

    private func addToFilteredWords(_ word: String) {
        // Get the path to FilteredWords.json in the app's documents directory
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent("FilteredWords.json")

        // Load existing filtered words from Documents directory, or create new file
        var filteredData: FilteredWordsData

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(FilteredWordsData.self, from: data) {
            // File exists in documents, load it
            filteredData = decoded
        } else if let bundlePath = Bundle.main.path(forResource: "FilteredWords", ofType: "json"),
                  let bundleData = try? Data(contentsOf: URL(fileURLWithPath: bundlePath)),
                  let decoded = try? JSONDecoder().decode(FilteredWordsData.self, from: bundleData) {
            // Copy from bundle to documents
            filteredData = decoded
        } else {
            // Create new with empty list
            filteredData = FilteredWordsData(commonWords: [])
        }

        // Add the new word if it's not already in the list
        let lowercasedWord = word.lowercased()
        if !filteredData.commonWords.contains(where: { $0.lowercased() == lowercasedWord }) {
            var updatedWords = filteredData.commonWords
            updatedWords.append(word)
            updatedWords.sort()
            filteredData = FilteredWordsData(commonWords: updatedWords)

            // Save to documents directory
            if let encoded = try? JSONEncoder().encode(filteredData) {
                try? encoded.write(to: fileURL)
                print("Added '\(word)' to filtered words list")
            }
        }
    }
}

struct TextScannerViewRepresentable: UIViewControllerRepresentable {
    @Binding var detectedTexts: [DetectedText]
    let scanRegion: CGRect
    @Binding var isFrozen: Bool

    func makeUIViewController(context: Context) -> TextScannerViewController {
        let controller = TextScannerViewController()
        controller.delegate = context.coordinator
        controller.scanRegion = scanRegion
        return controller
    }

    func updateUIViewController(_ uiViewController: TextScannerViewController, context: Context) {
        uiViewController.isFrozen = isFrozen
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
    weak var delegate: TextScannerDelegate?
    var scanRegion: CGRect = CGRect(x: 0.275, y: 0.4, width: 0.45, height: 0.117)
    var isFrozen: Bool = false
    private var lastScanTime: Date?
    private let scanInterval: TimeInterval = 1.0 // Scan every 1 second
    private var filteredWords: Set<String> = []

    override func viewDidLoad() {
        super.viewDidLoad()

        // Load filtered words from JSON
        loadFilteredWords()

        view.backgroundColor = UIColor.black
        captureSession = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
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

    private func loadFilteredWords() {
        // Try to load filtered words from Documents directory first (user customizations)
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent("FilteredWords.json")

        var filteredData: FilteredWordsData?

        // First try to load from Documents directory (user's custom list)
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(FilteredWordsData.self, from: data) {
            filteredData = decoded
            print("Loaded filtered words from Documents directory")
        } else if let bundlePath = Bundle.main.path(forResource: "FilteredWords", ofType: "json"),
                  let bundleData = try? Data(contentsOf: URL(fileURLWithPath: bundlePath)),
                  let decoded = try? JSONDecoder().decode(FilteredWordsData.self, from: bundleData) {
            // Fall back to bundle if no custom list exists
            filteredData = decoded
            print("Loaded filtered words from Bundle")
        }

        if let data = filteredData {
            // Convert to lowercase set for case-insensitive matching
            filteredWords = Set(data.commonWords.map { $0.lowercased() })
            print("Loaded \\(filteredWords.count) filtered words")
        } else {
            print("Could not load FilteredWords.json, using empty set")
        }
    }

    private func looksLikePartNumber(_ text: String) -> Bool {
        // Must be 3-20 characters
        guard text.count >= 3 && text.count <= 20 else { return false }

        // Must contain at least one letter or number
        let hasAlphanumeric = text.range(of: "[A-Za-z0-9]", options: .regularExpression) != nil
        guard hasAlphanumeric else { return false }

        // Filter out common words using the loaded dictionary
        let lowercasedText = text.lowercased()
        if filteredWords.contains(lowercasedText) {
            return false
        }

        // Should mostly be alphanumeric with common separators
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_./"))
        return text.rangeOfCharacter(from: allowedCharacters.inverted) == nil
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}
