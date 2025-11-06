import SwiftUI

struct SquawkDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let squawk: Squawk
    let onSquawkUpdated: () -> Void

    @State private var showingFixConfirmation = false
    @State private var fixNotes = ""
    @State private var isUpdating = false
    @State private var errorMessage: String?
    @State private var selectedPhotoUrl: String?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Severity Badge
                    HStack {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(severityColor(squawk.severity))
                                .frame(width: 16, height: 16)

                            Text(squawk.severity.displayName)
                                .font(.headline)
                                .foregroundColor(severityColor(squawk.severity))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(severityColor(squawk.severity).opacity(0.1))
                        .cornerRadius(8)

                        Spacer()

                        // Status Badge
                        Text(squawk.status.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(statusColor(squawk.status).opacity(0.2))
                            .foregroundColor(statusColor(squawk.status))
                            .cornerRadius(6)
                    }
                    .padding(.horizontal)

                    // Title
                    Text(squawk.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)

                    // Description
                    if let description = squawk.description, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(description)
                                .font(.body)
                        }
                        .padding(.horizontal)
                    }

                    Divider()
                        .padding(.horizontal)

                    // Reported Info
                    VStack(alignment: .leading, spacing: 8) {
                        infoRow(
                            label: "Reported By",
                            value: squawk.reportedByName ?? squawk.reportedByUsername ?? "Unknown"
                        )

                        infoRow(
                            label: "Reported At",
                            value: formatDateTime(squawk.reportedAt)
                        )

                        if let tailNumber = squawk.tailNumber {
                            infoRow(
                                label: "Aircraft",
                                value: tailNumber
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Fixed Info (if applicable)
                    if squawk.status == .fixed {
                        Divider()
                            .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Fixed Information")
                                .font(.headline)
                                .padding(.horizontal)

                            if let fixedByName = squawk.fixedByName ?? squawk.fixedByUsername {
                                infoRow(label: "Fixed By", value: fixedByName)
                            }

                            if let fixedAt = squawk.fixedAt {
                                infoRow(label: "Fixed At", value: formatDateTime(fixedAt))
                            }

                            if let notes = squawk.fixNotes, !notes.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Fix Notes")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Text(notes)
                                        .font(.body)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    // Photos
                    if let photos = squawk.photos, !photos.isEmpty {
                        Divider()
                            .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Photos")
                                .font(.headline)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(photos, id: \.self) { photoUrl in
                                        AsyncImage(url: URL(string: photoUrl)) { phase in
                                            switch phase {
                                            case .empty:
                                                ProgressView()
                                                    .frame(width: 150, height: 150)
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 150, height: 150)
                                                    .clipped()
                                                    .cornerRadius(8)
                                                    .onTapGesture {
                                                        selectedPhotoUrl = photoUrl
                                                    }
                                            case .failure:
                                                Rectangle()
                                                    .fill(Color.gray.opacity(0.3))
                                                    .frame(width: 150, height: 150)
                                                    .cornerRadius(8)
                                                    .overlay(
                                                        VStack {
                                                            Image(systemName: "exclamationmark.triangle")
                                                                .font(.title)
                                                            Text("Failed to load")
                                                                .font(.caption)
                                                        }
                                                        .foregroundColor(.gray)
                                                    )
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }

                    Spacer()

                    // Action Buttons
                    if squawk.status == .active {
                        Button(action: { showingFixConfirmation = true }) {
                            Label("Mark as Fixed", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Squawk Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Mark Squawk as Fixed", isPresented: $showingFixConfirmation) {
                TextField("Fix notes (optional)", text: $fixNotes)
                Button("Cancel", role: .cancel) {}
                Button("Confirm") {
                    markAsFixed()
                }
            } message: {
                Text("Has this squawk been fixed?\n\nOnce marked as fixed, the squawk will be moved to the fixed section.")
            }
            .fullScreenCover(item: Binding(
                get: { selectedPhotoUrl.map { PhotoItem(url: $0) } },
                set: { selectedPhotoUrl = $0?.url }
            )) { photoItem in
                FullScreenPhotoView(photoUrl: photoItem.url) {
                    selectedPhotoUrl = nil
                }
            }
        }
    }

    struct PhotoItem: Identifiable {
        let id = UUID()
        let url: String
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.body)
        }
        .padding(.horizontal)
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

    private func statusColor(_ status: SquawkStatus) -> Color {
        switch status {
        case .active:
            return .orange
        case .fixed:
            return .green
        case .deferred:
            return .blue
        }
    }

    private func formatDateTime(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }

    private func markAsFixed() {
        isUpdating = true
        errorMessage = nil

        Task {
            do {
                _ = try await APIService.shared.markSquawkFixed(
                    id: squawk.id,
                    fixNotes: fixNotes.isEmpty ? nil : fixNotes
                )

                onSquawkUpdated()
                dismiss()
            } catch {
                errorMessage = "Failed to update: \(error.localizedDescription)"
                isUpdating = false
            }
        }
    }
}

// MARK: - Full Screen Photo Viewer

struct FullScreenPhotoView: View {
    let photoUrl: String
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            AsyncImage(url: URL(string: photoUrl)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .tint(.white)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale *= delta
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                    if scale < 1.0 {
                                        withAnimation {
                                            scale = 1.0
                                        }
                                    } else if scale > 4.0 {
                                        withAnimation {
                                            scale = 4.0
                                        }
                                    }
                                }
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation {
                                if scale > 1.0 {
                                    scale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 2.0
                                }
                            }
                        }
                case .failure:
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                        Text("Failed to load photo")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                @unknown default:
                    EmptyView()
                }
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                Spacer()
            }
        }
    }
}
