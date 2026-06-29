import CoreLocation
import Foundation
import UIKit

struct LogExportContext {
    let isRunning: Bool
    let localIPAddresses: [String]
    let port: Int
    let connectedClientCount: Int
    let locationAuthorizationText: String
    let backgroundLocationEnabled: Bool
    let batteryLevel: Float
    let batteryState: UIDevice.BatteryState
    let lastLocation: LocationPayload?
    let accuracyText: String
    let includePreciseCoordinates: Bool
}

enum LogExportService {
    static func makeBriefDiagnostics(
        diagnostics: [DiagnosticItem],
        context: LogExportContext
    ) -> String {
        var lines: [String] = [
            "GNSS Server diagnostics",
            "Server running: \(context.isRunning ? "yes" : "no")",
            "Clients: \(context.connectedClientCount)",
            "IP: \(context.localIPAddresses.isEmpty ? "not found" : context.localIPAddresses.joined(separator: ", "))",
            "Port: \(context.port)",
            "Location permission: \(context.locationAuthorizationText)",
            "Accuracy: \(context.accuracyText)",
            ""
        ]

        lines.append("Items:")
        for item in diagnostics {
            lines.append("- \(item.title): \(item.action)")
        }

        return lines.joined(separator: "\n")
    }

    static func exportLogFile(context: LogExportContext) throws -> URL {
        let generatedAt = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var lines: [String] = [
            "GNSS Server Diagnostic Log",
            "Generated at: \(formatter.string(from: generatedAt))",
            "",
            "App version: \(appVersion)",
            "iOS version: \(UIDevice.current.systemVersion)",
            "Device model: \(UIDevice.current.model)",
            "Server state: \(context.isRunning ? "running" : "stopped")",
            "IP: \(context.localIPAddresses.isEmpty ? "not found" : context.localIPAddresses.joined(separator: ", "))",
            "Port: \(context.port)",
            "Connected clients: \(context.connectedClientCount)",
            "Location authorization: \(context.locationAuthorizationText)",
            "Background location enabled: \(context.backgroundLocationEnabled ? "yes" : "no")",
            "Battery level: \(batteryLevelText(context.batteryLevel))",
            "Battery state: \(batteryStateText(context.batteryState))",
            "Last location age: \(lastLocationAgeText(context.lastLocation))",
            "Current accuracy: \(context.accuracyText)",
            "Speed available: \(speedAvailableText(context.lastLocation))"
        ]

        if context.includePreciseCoordinates, let location = context.lastLocation {
            lines.append(String(format: "Precise coordinates: %.6f, %.6f", location.latitude, location.longitude))
        } else {
            lines.append("Precise coordinates: excluded")
        }

        let counters = AppLogger.shared.counterSnapshot()
        lines.append(contentsOf: [
            "Packets sent: \(counters.packetsSent)",
            "Heartbeats received: \(counters.heartbeatsReceived)",
            "Send errors: \(counters.sendErrors)",
            "",
            "Recent log entries:"
        ])

        for entry in AppLogger.shared.snapshot() {
            lines.append(
                "\(formatter.string(from: entry.date)) [\(entry.level.rawValue)] [\(entry.category.rawValue)] \(entry.message)"
            )
        }

        let filenameDate = formatter.string(from: generatedAt)
            .replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnss-server-\(filenameDate).log")

        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        AppLogger.shared.info(.export, "Diagnostic log exported to \(url.lastPathComponent)")
        return url
    }

    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = info?["CFBundleVersion"] as? String ?? "unknown"
        return "\(version) (\(build))"
    }

    private static func batteryLevelText(_ level: Float) -> String {
        guard level >= 0 else { return "unknown" }
        return "\(Int(level * 100))%"
    }

    private static func batteryStateText(_ state: UIDevice.BatteryState) -> String {
        switch state {
        case .unknown: return "unknown"
        case .unplugged: return "unplugged"
        case .charging: return "charging"
        case .full: return "full"
        @unknown default: return "unknown"
        }
    }

    private static func lastLocationAgeText(_ location: LocationPayload?) -> String {
        guard let location else { return "unavailable" }
        let locationDate = Date(timeIntervalSince1970: TimeInterval(location.timestamp) / 1_000)
        return String(format: "%.1f seconds", Date().timeIntervalSince(locationDate))
    }

    private static func speedAvailableText(_ location: LocationPayload?) -> String {
        guard let location else { return "no" }
        return location.speed > 0 ? "yes" : "no"
    }
}
