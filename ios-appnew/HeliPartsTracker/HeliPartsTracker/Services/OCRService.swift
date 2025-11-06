import Vision
import UIKit

class OCRService {
    static let shared = OCRService()

    private init() {}

    struct OCRResult {
        let text: String
        let confidence: Double
        let recognizedHours: Double?
    }

    func recognizeText(from image: UIImage, completion: @escaping (OCRResult?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                print("OCR Error: \(error)")
                completion(nil)
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(nil)
                return
            }

            var allText: [String] = []
            var totalConfidence: Float = 0

            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else { continue }
                allText.append(topCandidate.string)
                totalConfidence += topCandidate.confidence
            }

            let combinedText = allText.joined(separator: " ")
            let averageConfidence = observations.isEmpty ? 0 : Double(totalConfidence) / Double(observations.count)

            // Try to extract hours from the text
            let hours = self.extractHoursFromText(combinedText)

            let result = OCRResult(
                text: combinedText,
                confidence: averageConfidence * 100, // Convert to percentage
                recognizedHours: hours
            )

            completion(result)
        }

        // Configure for accurate text recognition
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try requestHandler.perform([request])
            } catch {
                print("Failed to perform OCR: \(error)")
                completion(nil)
            }
        }
    }

    // Extract hours from text - looks for patterns like "1234.5", "1234", etc.
    private func extractHoursFromText(_ text: String) -> Double? {
        // Common tach hour patterns
        let patterns = [
            // Hours with decimal: 1234.5, 1234.56
            #"(\d{1,5}\.\d{1,2})"#,
            // Hours without decimal: 1234
            #"(\d{3,5})(?!\d)"#,
            // Hours with comma separator: 1,234.5
            #"(\d{1,2},\d{3}\.\d{1,2})"#,
            #"(\d{1,2},\d{3})"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let nsText = text as NSString
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

                for match in matches {
                    if match.numberOfRanges > 1 {
                        let matchedString = nsText.substring(with: match.range(at: 1))
                        // Remove commas and convert to double
                        let cleanedString = matchedString.replacingOccurrences(of: ",", with: "")
                        if let hours = Double(cleanedString) {
                            // Sanity check - helicopter hours typically range from 0 to 50000
                            if hours >= 0 && hours <= 50000 {
                                return hours
                            }
                        }
                    }
                }
            }
        }

        return nil
    }

    // Helper function to recognize text synchronously (for testing)
    func recognizeTextSync(from image: UIImage) async -> OCRResult? {
        await withCheckedContinuation { continuation in
            recognizeText(from: image) { result in
                continuation.resume(returning: result)
            }
        }
    }

    // Analyze image quality to determine if it's suitable for OCR
    func analyzeImageQuality(image: UIImage) -> (isSuitable: Bool, reason: String?) {
        guard let cgImage = image.cgImage else {
            return (false, "Invalid image")
        }

        let width = cgImage.width
        let height = cgImage.height

        // Check minimum resolution
        if width < 400 || height < 400 {
            return (false, "Image resolution too low. Please take a clearer photo.")
        }

        // Check if image is too large (might indicate blur or excessive detail)
        if width > 8000 || height > 8000 {
            return (false, "Image resolution too high. Please crop to the tach area.")
        }

        return (true, nil)
    }
}

// Extension to save OCR result with image
extension OCRService {
    func processImageForLogbook(image: UIImage, completion: @escaping (UIImage, OCRResult?) -> Void) {
        // First check image quality
        let quality = analyzeImageQuality(image: image)
        guard quality.isSuitable else {
            print("Image quality issue: \(quality.reason ?? "Unknown")")
            completion(image, nil)
            return
        }

        // Perform OCR
        recognizeText(from: image) { result in
            DispatchQueue.main.async {
                completion(image, result)
            }
        }
    }
}
