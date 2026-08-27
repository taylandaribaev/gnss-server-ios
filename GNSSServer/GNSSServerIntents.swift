import AppIntents
import CoreLocation

struct StartGPSServerIntent: AppIntent {
    static var title: LocalizedStringResource = "shortcut.start.title"
    static var description = IntentDescription("shortcut.start.description")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        let coordinator = ServerCoordinator.shared

        guard !coordinator.isRunning else {
            return .result()
        }

        switch coordinator.locationAuthorizationStatus {
        case .denied, .restricted:
            throw GPSServerIntentError.locationDenied
        case .authorizedWhenInUse:
            AppLogger.shared.warn(.server, "Shortcut start: location access is not Always")
        default:
            break
        }

        coordinator.start()

        if let errorText = coordinator.errorText {
            throw GPSServerIntentError.startFailed(errorText)
        }

        return .result()
    }
}

struct StopGPSServerIntent: AppIntent {
    static var title: LocalizedStringResource = "shortcut.stop.title"
    static var description = IntentDescription("shortcut.stop.description")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        ServerCoordinator.shared.stop()
        return .result()
    }
}

enum GPSServerIntentError: Error, CustomLocalizedStringResourceConvertible {
    case locationDenied
    case startFailed(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .locationDenied:
            "shortcut.error.locationDenied"
        case .startFailed:
            "shortcut.error.startFailed"
        }
    }
}

struct GNSSServerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartGPSServerIntent(),
            phrases: [
                "Start GPS in \(.applicationName)",
                "Запустить GPS в \(.applicationName)",
            ],
            shortTitle: "shortcut.start.shortTitle",
            systemImageName: "location.fill"
        )
        AppShortcut(
            intent: StopGPSServerIntent(),
            phrases: [
                "Stop GPS in \(.applicationName)",
                "Остановить GPS в \(.applicationName)",
            ],
            shortTitle: "shortcut.stop.shortTitle",
            systemImageName: "location.slash.fill"
        )
    }
}
