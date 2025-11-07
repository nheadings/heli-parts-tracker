import SwiftUI

struct EditFlightView: View {
    @Environment(\.dismiss) private var dismiss
    let helicopterId: Int
    let existingFlight: Flight?
    let prefilledData: PrefilledFlightData?
    let onSave: () -> Void

    @State private var hobbsStart: String
    @State private var hobbsEnd: String = ""
    @State private var flightTime: String
    @State private var notes: String = ""
    @State private var departureTime: Date
    @State private var arrivalTime: Date

    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingHobbsEndWarning = false

    struct PrefilledFlightData {
        let hobbsStart: Double
        let flightTimeHours: Double
        let departureTime: Date
        let arrivalTime: Date
    }

    init(helicopterId: Int, existingFlight: Flight? = nil, prefilledData: PrefilledFlightData? = nil, onSave: @escaping () -> Void) {
        self.helicopterId = helicopterId
        self.existingFlight = existingFlight
        self.prefilledData = prefilledData
        self.onSave = onSave

        if let flight = existingFlight {
            // Editing existing flight
            _hobbsStart = State(initialValue: flight.hobbsStart.map { String(format: "%.1f", $0) } ?? "")
            _hobbsEnd = State(initialValue: flight.hobbsEnd.map { String(format: "%.1f", $0) } ?? "")
            _flightTime = State(initialValue: flight.flightTime.map { String(format: "%.2f", $0) } ?? "")
            _notes = State(initialValue: flight.notes ?? "")
            _departureTime = State(initialValue: Self.parseDate(flight.departureTime) ?? Date())
            _arrivalTime = State(initialValue: Self.parseDate(flight.arrivalTime) ?? Date())
        } else if let prefilled = prefilledData {
            // New flight from timer
            _hobbsStart = State(initialValue: String(format: "%.1f", prefilled.hobbsStart))
            _hobbsEnd = State(initialValue: "") // User must fill this
            _flightTime = State(initialValue: String(format: "%.2f", prefilled.flightTimeHours))
            _departureTime = State(initialValue: prefilled.departureTime)
            _arrivalTime = State(initialValue: prefilled.arrivalTime)
        } else {
            // New flight from scratch
            _hobbsStart = State(initialValue: "")
            _flightTime = State(initialValue: "")
            _departureTime = State(initialValue: Date())
            _arrivalTime = State(initialValue: Date())
        }
    }

    private static func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Hobbs Readings")) {
                    HStack {
                        Text("Start")
                            .frame(width: 80, alignment: .leading)
                        TextField("Hobbs Start", text: $hobbsStart)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }

                    HStack {
                        Text("End")
                            .frame(width: 80, alignment: .leading)
                        TextField("Hobbs End", text: $hobbsEnd)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }

                    if let tachTime = calculatedTachTime {
                        HStack {
                            Text("Tach Time")
                                .frame(width: 80, alignment: .leading)
                            Text(String(format: "%.2f hrs", tachTime))
                                .foregroundColor(.blue)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }

                Section(header: Text("Flight Time")) {
                    HStack {
                        Text("Flight Time")
                            .frame(width: 100, alignment: .leading)
                        TextField("Hours", text: $flightTime)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Text("hrs")
                            .foregroundColor(.secondary)
                    }
                    Text("From timer, but editable")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("Times")) {
                    DatePicker("Departure", selection: $departureTime, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Arrival", selection: $arrivalTime, displayedComponents: [.date, .hourAndMinute])
                }

                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(existingFlight != nil ? "Edit Flight" : "Log Flight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveFlight()
                    }
                    .disabled(isSaving)
                }
            }
            .alert("Hobbs End Required", isPresented: $showingHobbsEndWarning) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Hobbs End is required. Please enter the final Hobbs reading.")
            }
        }
    }

    private var calculatedTachTime: Double? {
        guard let start = Double(hobbsStart),
              let end = Double(hobbsEnd),
              end > start else {
            return nil
        }
        return end - start
    }

    private func saveFlight() {
        errorMessage = nil

        // Validate Hobbs End
        guard !hobbsEnd.trimmingCharacters(in: .whitespaces).isEmpty else {
            showingHobbsEndWarning = true
            return
        }

        guard let hobbsStartValue = Double(hobbsStart),
              let hobbsEndValue = Double(hobbsEnd),
              let flightTimeValue = Double(flightTime) else {
            errorMessage = "Please enter valid numbers for all fields"
            return
        }

        guard hobbsEndValue > hobbsStartValue else {
            errorMessage = "Hobbs End must be greater than Hobbs Start"
            return
        }

        guard flightTimeValue > 0 else {
            errorMessage = "Flight time must be greater than 0"
            return
        }

        isSaving = true

        Task {
            do {
                let formatter = ISO8601DateFormatter()
                let tachTime = hobbsEndValue - hobbsStartValue

                let flightCreate = FlightCreate(
                    hobbsStart: hobbsStartValue,
                    hobbsEnd: hobbsEndValue,
                    flightTime: flightTimeValue,
                    tachTime: tachTime,
                    departureTime: formatter.string(from: departureTime),
                    arrivalTime: formatter.string(from: arrivalTime),
                    hobbsPhotoUrl: nil,
                    ocrConfidence: nil,
                    notes: notes.isEmpty ? nil : notes
                )

                if let existingFlight = existingFlight {
                    // Update existing flight
                    _ = try await APIService.shared.updateFlight(id: existingFlight.id, flight: flightCreate)
                } else {
                    // Create new flight
                    _ = try await APIService.shared.createFlight(helicopterId: helicopterId, flight: flightCreate)
                }

                await MainActor.run {
                    onSave()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save flight: \(error.localizedDescription)"
                    isSaving = false
                }
            }
        }
    }
}
