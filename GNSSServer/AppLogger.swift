import Foundation
import OSLog

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warn = "WARN"
    case error = "ERROR"
}

enum LogCategory: String {
    case app = "App"
    case server = "Server"
    case client = "Client"
    case location = "Location"
    case network = "Network"
    case liveActivity = "LiveActivity"
    case export = "Export"
}

struct LogEntry {
    let date: Date
    let level: LogLevel
    let category: LogCategory
    let message: String
}

struct LogCounters {
    let packetsSent: Int
    let heartbeatsReceived: Int
    let sendErrors: Int
}

final class AppLogger {
    static let shared = AppLogger()

    private let lock = NSLock()
    private let capacity = 2_000
    private var entries: [LogEntry] = []
    private var packetsSent = 0
    private var heartbeatsReceived = 0
    private var sendErrors = 0

    private init() {}

    func debug(_ category: LogCategory, _ message: String) {
        log(.debug, category, message)
    }

    func info(_ category: LogCategory, _ message: String) {
        log(.info, category, message)
    }

    func warn(_ category: LogCategory, _ message: String) {
        log(.warn, category, message)
    }

    func error(_ category: LogCategory, _ message: String) {
        log(.error, category, message)
    }

    func recordPacketSent() {
        lock.withLock {
            packetsSent += 1
        }
    }

    func recordHeartbeatReceived() {
        lock.withLock {
            heartbeatsReceived += 1
        }
    }

    func recordSendError() {
        lock.withLock {
            sendErrors += 1
        }
    }

    func snapshot() -> [LogEntry] {
        lock.withLock {
            entries
        }
    }

    func counterSnapshot() -> LogCounters {
        lock.withLock {
            LogCounters(
                packetsSent: packetsSent,
                heartbeatsReceived: heartbeatsReceived,
                sendErrors: sendErrors
            )
        }
    }

    func clear() {
        lock.withLock {
            entries.removeAll()
            packetsSent = 0
            heartbeatsReceived = 0
            sendErrors = 0
        }
        info(.export, "Diagnostic logs cleared")
    }

    private func log(_ level: LogLevel, _ category: LogCategory, _ message: String) {
        let entry = LogEntry(date: Date(), level: level, category: category, message: message)

        lock.withLock {
            entries.append(entry)
            if entries.count > capacity {
                entries.removeFirst(entries.count - capacity)
            }
        }

        let logger = Logger(subsystem: "kz.taylan.gnssserver.ios", category: category.rawValue)
        switch level {
        case .debug:
            logger.debug("\(message, privacy: .public)")
        case .info:
            logger.info("\(message, privacy: .public)")
        case .warn:
            logger.warning("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
