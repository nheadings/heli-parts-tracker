import SwiftUI

struct MaintenanceTemplatesView: View {
    @State private var templates: [MaintenanceSchedule] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAddTemplate = false
    @State private var editingTemplate: MaintenanceSchedule?

    var body: some View {
        List {
            if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            } else {
                Section(header: Text("Flight View Templates (max 5)")) {
                    ForEach(templates.filter { $0.displayInFlightView == true }.sorted { ($0.displayOrder ?? 0) < ($1.displayOrder ?? 0) }) { template in
                        MaintenanceTemplateRow(template: template)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingTemplate = template
                            }
                    }
                }

                let otherTemplates = templates.filter { $0.displayInFlightView != true }
                if !otherTemplates.isEmpty {
                    Section(header: Text("Other Templates")) {
                        ForEach(otherTemplates.sorted { $0.title < $1.title }) { template in
                            MaintenanceTemplateRow(template: template)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingTemplate = template
                                }
                        }
                    }
                }
            }
        }
        .navigationTitle("Maintenance Templates")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddTemplate = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddTemplate) {
            EditMaintenanceTemplateView {
                loadTemplates()
            }
        }
        .sheet(item: $editingTemplate) { template in
            EditMaintenanceTemplateView(template: template) {
                loadTemplates()
            }
        }
        .task {
            loadTemplates()
        }
        .refreshable {
            loadTemplates()
        }
    }

    private func loadTemplates() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                templates = try await APIService.shared.getMaintenanceScheduleTemplates()
                isLoading = false
            } catch {
                errorMessage = "Failed to load templates: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

struct MaintenanceTemplateRow: View {
    let template: MaintenanceSchedule

    var body: some View {
        HStack(spacing: 12) {
            // Color indicator
            Circle()
                .fill(Color(hex: template.color ?? "#34C759"))
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(template.title)
                        .font(.headline)

                    if template.displayInFlightView == true {
                        Image(systemName: "eye")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }

                Text("Every \(Int(template.intervalHours ?? 0)) hours")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                if let threshold = template.thresholdWarning {
                    Text("Warning at \(threshold)hrs before due")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            if template.displayInFlightView == true, let order = template.displayOrder {
                Text("#\(order + 1)")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        MaintenanceTemplatesView()
    }
}
