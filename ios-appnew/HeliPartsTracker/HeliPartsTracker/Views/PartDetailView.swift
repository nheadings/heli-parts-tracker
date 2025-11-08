import SwiftUI

struct PartDetailView: View {
    let part: Part
    var conflictWarning: [Part]? = nil // Optional conflict warning from scanner
    @Environment(\.openURL) var openURL
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: PartsViewModel
    @ObservedObject private var pdfCache = PDFCacheService.shared
    @State private var showingAddQuantity = false
    @State private var quantityToAdd = ""
    @State private var showingDeleteConfirmation = false
    @State private var showingEditPart = false
    @State private var showingInstallPart = false
    @State private var showingPDFViewer = false
    @State private var pdfURLToShow: URL?
    @State private var pdfTypeToShow: PDFCacheService.PDFType?
    @State private var pdfSearchTerm: String = ""
    @State private var priceListPrice: String = ""
    @State private var isSearchingPriceList = false
    @State private var transactions: [InventoryTransaction] = []
    @State private var isLoadingTransactions = false

    var body: some View {
        List {
            // OCR CONFLICT WARNING BANNER
            if let conflicts = conflictWarning, !conflicts.isEmpty {
                let _ = print("⚠️ PartDetailView showing conflict warning for \(conflicts.count) parts")
            }
            if let conflicts = conflictWarning, !conflicts.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("OCR Warning: Longer Parts Exist")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                Text("Part '\(part.partNumber)' found, but longer variants exist. Verify this is correct.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }

                        DisclosureGroup("View \(conflicts.count) Longer Variant\(conflicts.count == 1 ? "" : "s")") {
                            ForEach(conflicts) { conflict in
                                NavigationLink(destination:
                                    PartDetailView(part: conflict)
                                        .environmentObject(viewModel)
                                ) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(conflict.partNumber)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text(conflict.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        if let manufacturer = conflict.manufacturer {
                                            Text("Mfg: \(manufacturer)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        .tint(.red)
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.red.opacity(0.1))
            }

            Section("Information") {
                DetailRow(label: "Part Number", value: part.partNumber)
                if let altPartNumber = part.alternatePartNumber {
                    DetailRow(label: "Alternate Part #", value: altPartNumber)
                }
                DetailRow(label: "Description", value: part.description)
                if let manufacturer = part.manufacturer {
                    DetailRow(label: "Manufacturer", value: manufacturer)
                }
                if let category = part.category {
                    DetailRow(label: "Category", value: category)
                }
                if let location = part.location {
                    DetailRow(label: "Location", value: location)
                }
            }

            Section("Inventory") {
                DetailRow(label: "In Stock", value: "\(part.quantityInStock)")
                if let minQty = part.minimumQuantity {
                    DetailRow(label: "Minimum Quantity", value: "\(minQty)")
                }
                if part.isLowStock {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("Low Stock Alert")
                            .foregroundColor(.red)
                    }
                }
            }

            if let price = part.unitPrice {
                Section("Pricing") {
                    DetailRow(label: "Unit Price", value: String(format: "$%.2f", price))
                    HStack {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("From October 2025 Price List")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Robinson Manuals Section
            if part.category == "R44" {
                Section("Robinson R44 Manuals") {
                    Button(action: {
                        openRobinsonIPC()
                    }) {
                        HStack {
                            Image(systemName: "book.closed.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("View in R44 IPC")
                                Text("Opens PDF and searches for \(part.partNumber)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                    }

                    Button(action: {
                        openRobinsonMM()
                    }) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading) {
                                Text("View in R44 Maintenance Manual")
                                Text("Opens PDF and searches for \(part.partNumber)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                    }

                    Button(action: {
                        openRobinsonPriceList()
                    }) {
                        HStack {
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading) {
                                Text("View in R44 Price List")
                                if isSearchingPriceList {
                                    HStack(spacing: 4) {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                        Text("Searching PDF...")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                } else if !priceListPrice.isEmpty {
                                    Text("Price: \(priceListPrice)")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                        .fontWeight(.semibold)
                                } else {
                                    Text("No price found in PDF")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                    }
                }
            }

            if let reorderUrl = part.reorderUrl, let url = URL(string: reorderUrl) {
                Section("Reorder") {
                    Button(action: {
                        openURL(url)
                    }) {
                        HStack {
                            Text("Open Vendor Website")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                    }
                }
            }

            if let qrCode = part.qrCode {
                Section("QR Code") {
                    if let image = generateQRCode(from: qrCode) {
                        Image(uiImage: image)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            Section("Actions") {
                Button(action: {
                    showingAddQuantity = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                        Text("Add Quantity")
                        Spacer()
                    }
                }

                Button(action: {
                    showingInstallPart = true
                }) {
                    HStack {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .foregroundColor(.blue)
                        Text("Install Part")
                        Spacer()
                    }
                }

                Button(action: {
                    showingEditPart = true
                }) {
                    HStack {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundColor(.orange)
                        Text("Edit Part")
                        Spacer()
                    }
                }

                Button(role: .destructive, action: {
                    showingDeleteConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("Remove Part")
                        Spacer()
                    }
                }
            }

            Section("History") {
                if isLoadingTransactions {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if transactions.isEmpty {
                    Text("No transactions")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(transactions) { transaction in
                        Group {
                            if let helicopterId = transaction.helicopterId, let tailNumber = transaction.helicopterTailNumber {
                                NavigationLink(destination: LogbookDashboardWrapper(helicopterId: helicopterId)) {
                                    TransactionRowView(transaction: transaction, showHelicopter: true)
                                }
                            } else {
                                TransactionRowView(transaction: transaction, showHelicopter: false)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Part Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            print("🔄 PartDetailView .task block started for part: \(part.partNumber)")
            await loadTransactions()
            // Preload IPC, MM, and Price List in background if they're cached
            if part.category == "R44" {
                print("📱 Preloading R44 PDFs...")
                pdfCache.preloadPDF(type: .r44IPC)
                pdfCache.preloadPDF(type: .r44MM)
                pdfCache.preloadPDF(type: .r44PriceList)
                // Search price list for current price
                await searchPriceListForPrice()
            }
            print("✅ PartDetailView .task block completed")
        }
        .sheet(isPresented: $showingAddQuantity) {
            NavigationView {
                Form {
                    Section("Add Quantity") {
                        TextField("Quantity to add", text: $quantityToAdd)
                            .keyboardType(.numberPad)
                    }
                }
                .navigationTitle("Add Quantity")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            showingAddQuantity = false
                            quantityToAdd = ""
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Add") {
                            if let qty = Int(quantityToAdd), qty > 0 {
                                Task {
                                    await addQuantity(qty)
                                    showingAddQuantity = false
                                    quantityToAdd = ""
                                }
                            }
                        }
                        .disabled(quantityToAdd.isEmpty || Int(quantityToAdd) == nil)
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditPart) {
            AddPartView(existingPart: part)
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showingInstallPart) {
            InstallPartOnHelicopterView(part: part)
        }
        .sheet(isPresented: $showingPDFViewer) {
            if let pdfURL = pdfURLToShow, let pdfType = pdfTypeToShow {
                PDFViewerWithSearch(
                    pdfURL: pdfURL,
                    initialSearchTerm: pdfSearchTerm,
                    preloadedDocument: pdfCache.getPreloadedDocument(type: pdfType)
                )
            }
        }
        .alert("Delete Part", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await deletePart()
                }
            }
        } message: {
            Text("Are you sure you want to delete this part? This action cannot be undone.")
        }
    }

    private func addQuantity(_ quantity: Int) async {
        let updatedPart = PartCreate(
            partNumber: part.partNumber,
            alternatePartNumber: part.alternatePartNumber,
            description: part.description,
            manufacturer: part.manufacturer,
            category: part.category,
            quantityInStock: part.quantityInStock + quantity,
            minimumQuantity: part.minimumQuantity,
            unitPrice: part.unitPrice,
            reorderUrl: part.reorderUrl,
            location: part.location,
            isLifeLimited: part.isLifeLimited ?? false
        )
        _ = await viewModel.updatePart(id: part.id, partData: updatedPart)
    }

    private func deletePart() async {
        await viewModel.deletePart(part)
        dismiss()
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let data = Data(string.utf8)
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            if let output = filter.outputImage {
                let transform = CGAffineTransform(scaleX: 10, y: 10)
                let scaledImage = output.transformed(by: transform)
                let context = CIContext()
                if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                    return UIImage(cgImage: cgImage)
                }
            }
        }
        return nil
    }

    private func openRobinsonIPC() {
        Task {
            await openManual(type: .r44IPC)
        }
    }

    private func openRobinsonMM() {
        Task {
            await openManual(type: .r44MM)
        }
    }

    private func openRobinsonPriceList() {
        Task {
            await openManual(type: .r44PriceList)
        }
    }

    private func searchPriceListForPrice() async {
        // Only search if price list is cached
        guard let priceListURL = pdfCache.getCachedPDFURL(type: .r44PriceList) else {
            print("⚠️ Price list not downloaded")
            priceListPrice = ""
            return
        }

        print("🔍 Starting price search for: \(part.partNumber)")
        isSearchingPriceList = true
        priceListPrice = ""

        // Load and search PDF
        guard let document = PDFDocument(url: priceListURL) else {
            print("❌ Failed to load price list PDF")
            isSearchingPriceList = false
            return
        }

        print("📖 Loaded price list: \(document.pageCount) pages")

        DispatchQueue.global(qos: .utility).async {
            var foundPrice = ""

            // Search all pages for the part number
            for pageNum in 0..<document.pageCount {
                guard let page = document.page(at: pageNum) else { continue }
                guard let text = page.string else { continue }

                // Look for line with this part number
                let lines = text.components(separatedBy: "\n")
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)

                    // Check if line starts with our part number
                    if trimmed.hasPrefix(self.part.partNumber + " ") ||
                       trimmed.hasPrefix(self.part.partNumber + "\t") {
                        print("📄 Found on page \(pageNum + 1): \(trimmed)")

                        // Extract price using regex (may or may not have $ after)
                        let pattern = #"(\d{1,3}(?:,\d{3})*\.\d{2})\$?"#
                        if let regex = try? NSRegularExpression(pattern: pattern),
                           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
                           let priceRange = Range(match.range(at: 1), in: trimmed) {
                            let priceStr = String(trimmed[priceRange]).replacingOccurrences(of: ",", with: "")
                            print("💰 Extracted: \(priceStr)")

                            if let priceVal = Double(priceStr) {
                                foundPrice = String(format: "$%.2f (Oct 2025)", priceVal)
                                print("✅ Success: \(foundPrice)")
                            }
                        } else {
                            print("❌ Regex failed on: \(trimmed)")
                        }
                        break
                    }
                }
                if !foundPrice.isEmpty { break }
            }

            if foundPrice.isEmpty {
                print("⚠️ No price found for '\(self.part.partNumber)'")
            }

            DispatchQueue.main.async {
                self.priceListPrice = foundPrice
                self.isSearchingPriceList = false
            }
        }
    }

    private func openManual(type: PDFCacheService.PDFType) async {
        // Check if PDF is cached
        if let cachedURL = pdfCache.getCachedPDFURL(type: type) {
            print("📁 Found cached PDF at: \(cachedURL)")

            // Verify file actually exists
            let fileExists = FileManager.default.fileExists(atPath: cachedURL.path)
            print("📄 File exists: \(fileExists)")

            if fileExists {
                // Open cached PDF (preloaded document will be used if available)
                let preloaded = pdfCache.getPreloadedDocument(type: type)
                print("💾 Preloaded document available: \(preloaded != nil)")

                pdfURLToShow = cachedURL
                pdfTypeToShow = type
                pdfSearchTerm = part.partNumber
                showingPDFViewer = true
            } else {
                print("❌ Cached file doesn't exist, forcing download")
                // File missing, force download
                pdfCache.errorMessage = "Re-downloading \(type.rawValue)..."

                do {
                    let url = await pdfCache.getConfiguredURL(type: type)
                    let fileURL = try await pdfCache.downloadPDF(type: type, fromURL: url)

                    // Preload the document now that it's downloaded
                    pdfCache.preloadPDF(type: type)

                    // Open the downloaded PDF
                    pdfURLToShow = fileURL
                    pdfTypeToShow = type
                    pdfSearchTerm = part.partNumber
                    showingPDFViewer = true
                } catch {
                    pdfCache.errorMessage = "Failed to download: \(error.localizedDescription)"
                }
            }
        } else {
            print("📥 No cached PDF, downloading...")
            // Need to download first
            pdfCache.errorMessage = "Downloading \(type.rawValue)... This may take a minute."

            do {
                let url = await pdfCache.getConfiguredURL(type: type)
                let fileURL = try await pdfCache.downloadPDF(type: type, fromURL: url)

                // Preload the document now that it's downloaded
                pdfCache.preloadPDF(type: type)

                // Open the downloaded PDF
                pdfURLToShow = fileURL
                pdfTypeToShow = type
                pdfSearchTerm = part.partNumber
                showingPDFViewer = true
            } catch {
                pdfCache.errorMessage = "Failed to download: \(error.localizedDescription)"
            }
        }
    }

    private func loadTransactions() async {
        isLoadingTransactions = true
        do {
            transactions = try await APIService.shared.getPartTransactions(partId: part.id)
        } catch {
            print("Failed to load transactions: \(error)")
        }
        isLoadingTransactions = false
    }

    private func formatQuantityChange(_ change: Int) -> String {
        if change > 0 {
            return "+\(change)"
        } else {
            return "\(change)"
        }
    }

    private func formatTransactionDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

// Wrapper view to provide LogbookViewModel for navigation from parts
struct LogbookDashboardWrapper: View {
    let helicopterId: Int
    @StateObject private var viewModel = LogbookViewModel()

    var body: some View {
        LogbookDashboardView(helicopterId: helicopterId)
            .environmentObject(viewModel)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
    }
}

struct TransactionRowView: View {
    let transaction: InventoryTransaction
    let showHelicopter: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(transaction.transactionType.capitalized)
                    .font(.headline)
                Spacer()
                Text(formatQuantityChange(transaction.quantityChange))
                    .font(.headline)
                    .foregroundColor(transaction.quantityChange > 0 ? .green : .red)
            }

            if showHelicopter, let tailNumber = transaction.helicopterTailNumber {
                HStack {
                    Image(systemName: "airplane")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(tailNumber)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }

            if let username = transaction.performedByUsername {
                HStack {
                    Image(systemName: "person.circle")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(username)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            HStack {
                Text("Qty After: \(transaction.quantityAfter)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatTransactionDate(transaction.transactionDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if let notes = transaction.notes {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(.vertical, 4)
    }

    private func formatQuantityChange(_ change: Int) -> String {
        if change > 0 {
            return "+\(change)"
        } else {
            return "\(change)"
        }
    }

    private func formatTransactionDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - PDF Viewer with Search

import PDFKit

struct PDFViewerWithSearch: View {
    let pdfURL: URL
    let initialSearchTerm: String
    let preloadedDocument: PDFDocument?
    @Environment(\.dismiss) var dismiss
    @State private var searchTerm: String = ""
    @State private var isSearching = false
    @State private var isLoadingPDF = true
    @State private var resultCount = 0
    @State private var currentResultIndex = 0
    @State private var searchTrigger = UUID()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search in manual", text: $searchTerm)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .onSubmit {
                                searchTrigger = UUID()
                            }

                        if !searchTerm.isEmpty {
                            Button(action: {
                                searchTerm = ""
                                resultCount = 0
                                currentResultIndex = 0
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }

                        Button(action: {
                            searchTrigger = UUID()
                        }) {
                            Text("Search")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .disabled(searchTerm.isEmpty)
                    }
                    .padding(.horizontal)

                    // Result navigation or no results message
                    if !isSearching && !searchTerm.isEmpty {
                        if resultCount > 0 {
                            HStack {
                                Text("\(currentResultIndex + 1) of \(resultCount)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Button(action: {
                                    if currentResultIndex > 0 {
                                        currentResultIndex -= 1
                                    }
                                }) {
                                    Image(systemName: "chevron.up")
                                }
                                .disabled(currentResultIndex == 0)

                                Button(action: {
                                    if currentResultIndex < resultCount - 1 {
                                        currentResultIndex += 1
                                    }
                                }) {
                                    Image(systemName: "chevron.down")
                                }
                                .disabled(currentResultIndex >= resultCount - 1)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                            .background(Color(.systemGroupedBackground))
                        } else {
                            HStack {
                                Image(systemName: "exclamationmark.circle")
                                    .foregroundColor(.orange)
                                Text("No results found for '\(searchTerm)'")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                            .background(Color(.systemGroupedBackground))
                        }
                    }
                }
                .padding(.vertical, 8)
                .background(Color(.systemBackground))

                Divider()

                // PDF Viewer
                ZStack {
                    PDFViewerRepresentable(
                        pdfURL: pdfURL,
                        preloadedDocument: preloadedDocument,
                        searchTerm: searchTerm,
                        searchTrigger: searchTrigger,
                        currentResultIndex: $currentResultIndex,
                        isSearching: $isSearching,
                        isLoadingPDF: $isLoadingPDF,
                        resultCount: $resultCount
                    )

                    // Loading PDF overlay
                    if isLoadingPDF {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Loading manual...")
                                .font(.headline)
                        }
                        .padding(30)
                        .background(Color(.systemBackground).opacity(0.95))
                        .cornerRadius(12)
                        .shadow(radius: 10)
                    }

                    // Searching overlay
                    if isSearching && !isLoadingPDF {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Searching for '\(searchTerm)'...")
                                .font(.headline)
                            Text("Searching 1,000+ pages...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(30)
                        .background(Color(.systemBackground).opacity(0.95))
                        .cornerRadius(12)
                        .shadow(radius: 10)
                    }
                }
            }
            .navigationTitle("Manual")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            searchTerm = initialSearchTerm
            if !initialSearchTerm.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    searchTrigger = UUID()
                }
            }
        }
    }
}

struct PDFViewerRepresentable: UIViewRepresentable {
    let pdfURL: URL
    let preloadedDocument: PDFDocument?
    let searchTerm: String
    let searchTrigger: UUID
    @Binding var currentResultIndex: Int
    @Binding var isSearching: Bool
    @Binding var isLoadingPDF: Bool
    @Binding var resultCount: Int

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.pageBreakMargins = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

        context.coordinator.pdfView = pdfView

        // Use preloaded document if available (instant!), otherwise load from disk
        if let document = preloadedDocument {
            // Instant - already in memory
            pdfView.document = document
            context.coordinator.document = document
            isLoadingPDF = false

            // Fix scale for rotated pages
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
            }
        } else {
            // Load from disk in background
            Task {
                if let document = PDFDocument(url: pdfURL) {
                    await MainActor.run {
                        pdfView.document = document
                        context.coordinator.document = document
                        isLoadingPDF = false

                        // Fix scale for rotated pages
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
                        }
                    }
                } else {
                    // Failed to load PDF
                    print("❌ Failed to load PDF from \(pdfURL)")
                    await MainActor.run {
                        isLoadingPDF = false
                    }
                }
            }
        }

        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        // Handle search trigger changes
        if context.coordinator.lastSearchTrigger != searchTrigger && !searchTerm.isEmpty {
            context.coordinator.lastSearchTrigger = searchTrigger
            context.coordinator.performSearch(searchTerm: searchTerm)
        }

        // Handle result navigation
        if context.coordinator.lastResultIndex != currentResultIndex {
            context.coordinator.lastResultIndex = currentResultIndex
            context.coordinator.goToResult(index: currentResultIndex)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            isSearching: $isSearching,
            resultCount: $resultCount
        )
    }

    class Coordinator {
        var pdfView: PDFView?
        var document: PDFDocument?
        var searchSelections: [PDFSelection] = []
        var lastSearchTrigger: UUID = UUID()
        var lastResultIndex: Int = 0
        @Binding var isSearching: Bool
        @Binding var resultCount: Int

        init(isSearching: Binding<Bool>, resultCount: Binding<Int>) {
            _isSearching = isSearching
            _resultCount = resultCount
        }

        func reset() {
            searchSelections = []
            lastSearchTrigger = UUID()
            lastResultIndex = 0
            document = nil
            pdfView?.highlightedSelections = nil
            pdfView?.clearSelection()
        }

        func performSearch(searchTerm: String) {
            if document == nil {
                document = pdfView?.document
            }

            guard let pdfView = pdfView, let document = document else { return }

            DispatchQueue.main.async {
                self.isSearching = true
            }

            DispatchQueue.global(qos: .userInitiated).async {
                let selections = document.findString(searchTerm, withOptions: .caseInsensitive)

                DispatchQueue.main.async {
                    self.searchSelections = selections
                    self.resultCount = selections.count

                    if !selections.isEmpty {
                        pdfView.highlightedSelections = selections
                        pdfView.go(to: selections[0])
                        pdfView.setCurrentSelection(selections[0], animate: true)
                    }

                    self.isSearching = false
                }
            }
        }

        func goToResult(index: Int) {
            guard let pdfView = pdfView, index < searchSelections.count else { return }
            let selection = searchSelections[index]
            pdfView.go(to: selection)
            pdfView.setCurrentSelection(selection, animate: true)
        }
    }
}

