import Foundation
import Combine

@MainActor
class FlightTimerManager: ObservableObject {
    @Published var isRunning = false
    @Published var isPaused = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var startHobbs: Double?
    @Published var helicopterId: Int?

    private var startTime: Date?
    private var pausedTime: Date?
    private var accumulatedTime: TimeInterval = 0
    private var timer: Timer?

    private let defaults = UserDefaults.standard
    private let startTimeKey = "flightTimerStartTime"
    private let pausedTimeKey = "flightTimerPausedTime"
    private let accumulatedTimeKey = "flightTimerAccumulatedTime"
    private let startHobbsKey = "flightTimerStartHobbs"
    private let helicopterIdKey = "flightTimerHelicopterId"
    private let isRunningKey = "flightTimerIsRunning"
    private let isPausedKey = "flightTimerIsPaused"

    init() {
        loadState()
        if isRunning {
            startTimer()
        }
    }

    func startFlight(helicopterId: Int, currentHobbs: Double) {
        self.helicopterId = helicopterId
        self.startHobbs = currentHobbs
        self.startTime = Date()
        self.isRunning = true
        self.isPaused = false
        self.accumulatedTime = 0
        self.elapsedTime = 0

        saveState()
        startTimer()
    }

    func pauseFlight() {
        guard isRunning, !isPaused else { return }

        pausedTime = Date()
        isPaused = true

        if let start = startTime {
            accumulatedTime += Date().timeIntervalSince(start)
        }

        timer?.invalidate()
        timer = nil
        saveState()
    }

    func resumeFlight() {
        guard isRunning, isPaused else { return }

        startTime = Date()
        pausedTime = nil
        isPaused = false

        saveState()
        startTimer()
    }

    func endFlight() -> (startHobbs: Double, elapsedTime: TimeInterval, helicopterId: Int)? {
        guard let startHobbs = startHobbs, let helicopterId = helicopterId else {
            return nil
        }

        // Calculate final elapsed time
        if let start = startTime, !isPaused {
            accumulatedTime += Date().timeIntervalSince(start)
        }
        let finalTime = accumulatedTime

        // Store values before reset
        let result = (startHobbs: startHobbs, elapsedTime: finalTime, helicopterId: helicopterId)

        // Reset everything
        reset()

        return result
    }

    func cancelFlight() {
        reset()
    }

    private func reset() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        isPaused = false
        elapsedTime = 0
        startTime = nil
        pausedTime = nil
        accumulatedTime = 0
        startHobbs = nil
        helicopterId = nil
        clearState()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateElapsedTime()
            }
        }
        RunLoop.current.add(timer!, forMode: .common)
    }

    private func updateElapsedTime() {
        guard let start = startTime, !isPaused else { return }
        elapsedTime = accumulatedTime + Date().timeIntervalSince(start)
    }

    // MARK: - Persistence

    private func saveState() {
        defaults.set(startTime?.timeIntervalSince1970, forKey: startTimeKey)
        defaults.set(pausedTime?.timeIntervalSince1970, forKey: pausedTimeKey)
        defaults.set(accumulatedTime, forKey: accumulatedTimeKey)
        defaults.set(startHobbs, forKey: startHobbsKey)
        defaults.set(helicopterId, forKey: helicopterIdKey)
        defaults.set(isRunning, forKey: isRunningKey)
        defaults.set(isPaused, forKey: isPausedKey)
    }

    private func loadState() {
        guard defaults.bool(forKey: isRunningKey) else { return }

        isRunning = true
        isPaused = defaults.bool(forKey: isPausedKey)
        accumulatedTime = defaults.double(forKey: accumulatedTimeKey)
        startHobbs = defaults.object(forKey: startHobbsKey) as? Double
        helicopterId = defaults.object(forKey: helicopterIdKey) as? Int

        if let startTimeInterval = defaults.object(forKey: startTimeKey) as? TimeInterval {
            startTime = Date(timeIntervalSince1970: startTimeInterval)
        }

        if let pausedTimeInterval = defaults.object(forKey: pausedTimeKey) as? TimeInterval {
            pausedTime = Date(timeIntervalSince1970: pausedTimeInterval)
        }

        // Update elapsed time
        if !isPaused, let start = startTime {
            elapsedTime = accumulatedTime + Date().timeIntervalSince(start)
        } else {
            elapsedTime = accumulatedTime
        }
    }

    private func clearState() {
        defaults.removeObject(forKey: startTimeKey)
        defaults.removeObject(forKey: pausedTimeKey)
        defaults.removeObject(forKey: accumulatedTimeKey)
        defaults.removeObject(forKey: startHobbsKey)
        defaults.removeObject(forKey: helicopterIdKey)
        defaults.removeObject(forKey: isRunningKey)
        defaults.removeObject(forKey: isPausedKey)
    }

    // MARK: - Helpers

    func formattedElapsedTime() -> String {
        let hours = Int(elapsedTime) / 3600
        let minutes = Int(elapsedTime) / 60 % 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    func elapsedHours() -> Double {
        return elapsedTime / 3600.0
    }
}
