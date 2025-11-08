import Foundation
import UIKit
import Combine
import PDFKit

@MainActor
class PDFCacheService: ObservableObject {
    static let shared = PDFCacheService()

    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var errorMessage: String?

    private let fileManager = FileManager.default
    private let documentsDirectory: URL
    private var preloadedDocuments: [PDFType: PDFDocument] = [:]
    private var cachedURLs: [String: String] = [:]
    private var urlsLastFetched: Date?

    enum PDFType: String, CaseIterable {
        case r44IPC = "R44 IPC"
        case r44MM = "R44 Maintenance Manual"
        case r22IPC = "R22 IPC"
        case r22MM = "R22 Maintenance Manual"
        case r66IPC = "R66 IPC"
        case r66MM = "R66 Maintenance Manual"

        var filename: String {
            switch self {
            case .r44IPC: return "r44_ipc.pdf"
            case .r44MM: return "r44_mm.pdf"
            case .r22IPC: return "r22_ipc.pdf"
            case .r22MM: return "r22_mm.pdf"
            case .r66IPC: return "r66_ipc.pdf"
            case .r66MM: return "r66_mm.pdf"
            }
        }

        var metadataKey: String {
            return "pdfCache_\(filename)"
        }

        var urlKey: String {
            return "pdfURL_\(filename)"
        }

        var defaultURL: String {
            switch self {
            case .r44IPC: return "https://robinsonstrapistorprod.blob.core.windows.net/uploads/assets/r44_ipc_full_book_90d807fd56.pdf"
            case .r44MM: return "https://robinsonstrapistorprod.blob.core.windows.net/uploads/assets/r44_mm_full_book_a0b0b62448.pdf"
            case .r22IPC: return "https://robinsonstrapistorprod.blob.core.windows.net/uploads/assets/r22_ipc_full_book_856e8fc9ac.pdf"
            case .r22MM: return "https://robinsonstrapistorprod.blob.core.windows.net/uploads/assets/r22_mm_full_book_f51b33a19f.pdf"
            case .r66IPC: return "https://robinsonstrapistorprod.blob.core.windows.net/uploads/assets/r66_ipc_full_book_1dc86a7aea.pdf"
            case .r66MM: return "https://robinsonstrapistorprod.blob.core.windows.net/uploads/assets/r66_mm_full_book_b5f84e0595.pdf"
            }
        }
    }

    /// Get configured URL for PDF type (fetches from backend)
    func getConfiguredURL(type: PDFType) async -> String {
        // Refresh URLs from backend if needed (cache for 1 hour)
        await refreshURLsIfNeeded()

        // Map PDFType to backend manual_type key
        let manualTypeKey = type.filename.replacingOccurrences(of: ".pdf", with: "")
        return cachedURLs[manualTypeKey] ?? type.defaultURL
    }

    /// Save custom URL for PDF type (saves to backend)
    func saveURL(type: PDFType, url: String) async throws {
        let manualTypeKey = type.filename.replacingOccurrences(of: ".pdf", with: "")
        _ = try await APIService.shared.updateManualURL(
            manualType: manualTypeKey,
            url: url,
            description: type.rawValue
        )
        // Refresh URLs from backend
        await refreshURLs()
    }

    /// Fetch latest URLs from backend
    private func refreshURLs() async {
        do {
            let urls = try await APIService.shared.getManualURLs()
            cachedURLs = urls.mapValues { $0.url }
            urlsLastFetched = Date()
        } catch {
            print("Failed to fetch manual URLs: \(error)")
        }
    }

    /// Refresh URLs if cache is stale (>1 hour old)
    private func refreshURLsIfNeeded() async {
        guard let lastFetched = urlsLastFetched else {
            await refreshURLs()
            return
        }

        let oneHourAgo = Date().addingTimeInterval(-3600)
        if lastFetched < oneHourAgo {
            await refreshURLs()
        }
    }

    private init() {
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - Public Methods

    /// Get local file URL if cached, nil if not downloaded
    func getCachedPDFURL(type: PDFType) -> URL? {
        let fileURL = documentsDirectory.appendingPathComponent(type.filename)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        return fileURL
    }

    /// Check if PDF is cached
    func isCached(type: PDFType) -> Bool {
        return getCachedPDFURL(type: type) != nil
    }

    /// Check if cached PDF is older than 7 days
    func isStale(type: PDFType) -> Bool {
        guard let metadata = getMetadata(type: type) else {
            return true
        }

        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        return metadata.downloadDate < sevenDaysAgo
    }

    /// Get days since last download
    func daysSinceDownload(type: PDFType) -> Int? {
        guard let metadata = getMetadata(type: type) else {
            return nil
        }

        let days = Calendar.current.dateComponents([.day], from: metadata.downloadDate, to: Date()).day
        return days
    }

    /// Download PDF from URL and cache it
    func downloadPDF(type: PDFType, fromURL urlString: String) async throws -> URL {
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "PDFCache", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        await MainActor.run {
            isDownloading = true
            downloadProgress = 0.0
            errorMessage = nil
        }

        // Download file
        let (tempURL, response) = try await URLSession.shared.download(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "PDFCache", code: -2, userInfo: [NSLocalizedDescriptionKey: "Download failed"])
        }

        // Move to documents directory
        let fileURL = documentsDirectory.appendingPathComponent(type.filename)

        // Remove old file if exists
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }

        try fileManager.moveItem(at: tempURL, to: fileURL)

        // Save metadata
        let metadata = PDFMetadata(
            downloadDate: Date(),
            sourceURL: urlString,
            fileSize: try fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? Int64 ?? 0
        )
        saveMetadata(type: type, metadata: metadata)

        await MainActor.run {
            isDownloading = false
            downloadProgress = 1.0
        }

        return fileURL
    }

    /// Delete cached PDF
    func deleteCachedPDF(type: PDFType) throws {
        let fileURL = documentsDirectory.appendingPathComponent(type.filename)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        UserDefaults.standard.removeObject(forKey: type.metadataKey)
        preloadedDocuments.removeValue(forKey: type)
    }

    /// Preload PDF into memory in background (call this when user might need it soon)
    func preloadPDF(type: PDFType) {
        // Don't reload if already preloaded
        guard preloadedDocuments[type] == nil else { return }

        guard let fileURL = getCachedPDFURL(type: type) else { return }

        Task.detached(priority: .background) {
            if let document = PDFDocument(url: fileURL) {
                await MainActor.run {
                    self.preloadedDocuments[type] = document
                }
            }
        }
    }

    /// Get preloaded PDF document (instant if preloaded, nil if not)
    func getPreloadedDocument(type: PDFType) -> PDFDocument? {
        return preloadedDocuments[type]
    }

    // MARK: - Private Methods

    private func saveMetadata(type: PDFType, metadata: PDFMetadata) {
        if let encoded = try? JSONEncoder().encode(metadata) {
            UserDefaults.standard.set(encoded, forKey: type.metadataKey)
        }
    }

    private func getMetadata(type: PDFType) -> PDFMetadata? {
        guard let data = UserDefaults.standard.data(forKey: type.metadataKey),
              let metadata = try? JSONDecoder().decode(PDFMetadata.self, from: data) else {
            return nil
        }
        return metadata
    }
}

// MARK: - Metadata Model

struct PDFMetadata: Codable {
    let downloadDate: Date
    let sourceURL: String
    let fileSize: Int64
}
