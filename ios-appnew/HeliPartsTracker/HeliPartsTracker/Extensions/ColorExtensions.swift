import SwiftUI
import Foundation

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func toHex() -> String {
        guard let components = UIColor(self).cgColor.components else { return "#000000" }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}

// MARK: - Date Formatting Utilities
enum DateFormatting {
    /// Formats an ISO8601 date string to local time with date and time (no seconds)
    /// Example: "Nov 7, 2025 at 3:45 PM"
    static func formatDateTime(_ dateString: String) -> String {
        // Try parsing with fractional seconds first
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var date = formatter.date(from: dateString)

        // If that fails, try without fractional seconds
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: dateString)
        }

        guard let validDate = date else {
            return dateString
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short  // Shows time without seconds
        displayFormatter.timeZone = .current  // Explicitly use device's local timezone
        return displayFormatter.string(from: validDate)
    }

    /// Formats an ISO8601 date string to local date only (no time)
    /// Example: "Nov 7, 2025"
    static func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var date = formatter.date(from: dateString)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: dateString)
        }

        guard let validDate = date else {
            return dateString
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .none
        displayFormatter.timeZone = .current  // Explicitly use device's local timezone
        return displayFormatter.string(from: validDate)
    }

    /// Formats an ISO8601 date string to short date and time (no seconds)
    /// Example: "11/7/25, 3:45 PM"
    static func formatShortDateTime(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var date = formatter.date(from: dateString)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: dateString)
        }

        guard let validDate = date else {
            return dateString
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .short
        displayFormatter.timeStyle = .short  // Shows time without seconds
        displayFormatter.timeZone = .current  // Explicitly use device's local timezone
        return displayFormatter.string(from: validDate)
    }

    /// Formats an ISO8601 date string to long date and time (no seconds)
    /// Example: "November 7, 2025 at 3:45 PM"
    static func formatLongDateTime(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var date = formatter.date(from: dateString)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: dateString)
        }

        guard let validDate = date else {
            return dateString
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .long
        displayFormatter.timeStyle = .short  // Shows time without seconds
        displayFormatter.timeZone = .current  // Explicitly use device's local timezone
        return displayFormatter.string(from: validDate)
    }

    /// Converts a Date object to ISO8601 string in UTC timezone for sending to backend
    /// Example: Date(2025-11-07 8:18 PM EST) -> "2025-11-08T01:18:00Z"
    static func toISO8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        // ISO8601DateFormatter automatically uses UTC, but let's be explicit
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
}
