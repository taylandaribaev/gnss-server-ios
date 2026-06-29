import CoreLocation
import Foundation
import UIKit

@MainActor
final class ServerCoordinator: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var connectedClientCount = 0
    @Published private(set) var statusText = "Остановлен"
    @Published private(set) var errorText: String?
    @Published private(set) var lastLocation: LocationPayload?
    @Published private(set) var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var locationAccuracyAuthorization: CLAccuracyAuthorization = .reducedAccuracy
    @Published private(set) var locationAuthorizationText = "Не запрошено"
    @Published private(set) var precisionText = "Неизвестно"
    @Published private(set) var shouldShowLocationPermissionButton = true
    @Published private(set) var localIPAddresses: [String] = []
    @Published private(set) var batteryState: UIDevice.BatteryState = .unknown
    @Published private(set) var batteryLevel: Float = UIDevice.current.batteryLevel

    private let locationService = LocationService()
    private let tcpServer = TCPServer()
    private var addressRefreshTask: Task<Void, Never>?
    private var batteryStateObserver: NSObjectProtocol?
    private var batteryLevelObserver: NSObjectProtocol?

    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        batteryState = UIDevice.current.batteryState
        batteryLevel = UIDevice.current.batteryLevel
        batteryStateObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.batteryState = UIDevice.current.batteryState
                self?.batteryLevel = UIDevice.current.batteryLevel
            }
        }
        batteryLevelObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.batteryLevel = UIDevice.current.batteryLevel
            }
        }

        locationService.onLocation = { [weak self] location in
            Task { @MainActor in
                self?.handleLocation(location)
            }
        }
        locationService.onAuthorizationChange = { [weak self] status, accuracy in
            Task { @MainActor in
                self?.updateAuthorization(status: status, accuracy: accuracy)
            }
        }
        tcpServer.onClientCountChange = { [weak self] count in
            Task { @MainActor in
                self?.connectedClientCount = count
                if self?.isRunning == true {
                    LiveActivityService.shared.update(
                        status: self?.lastLocation == nil
                            ? "Ожидание геопозиции"
                            : "Передача геопозиции",
                        clientCount: count,
                        locationDate: self?.lastLocation.map {
                            Date(timeIntervalSince1970: TimeInterval($0.timestamp) / 1_000)
                        },
                        force: true
                    )
                }
            }
        }
        tcpServer.onFailure = { [weak self] error in
            Task { @MainActor in
                self?.errorText = error.localizedDescription
                self?.statusText = "Ошибка сервера"
                self?.isRunning = false
                self?.locationService.stop()
            }
        }

        updateAuthorization(
            status: locationService.authorizationStatus,
            accuracy: locationService.accuracyAuthorization
        )
        refreshLocalIPAddresses()
    }

    deinit {
        if let batteryStateObserver {
            NotificationCenter.default.removeObserver(batteryStateObserver)
        }
        if let batteryLevelObserver {
            NotificationCenter.default.removeObserver(batteryLevelObserver)
        }
        UIDevice.current.isBatteryMonitoringEnabled = false
    }

    func requestPermissions() {
        locationService.requestAuthorization()
    }

    func start() {
        guard !isRunning else { return }

        AppLogger.shared.info(.server, "Server start requested")
        errorText = nil
        requestPermissions()

        do {
            try tcpServer.start()
            isRunning = true
            statusText = "Ожидание координат"
            AppLogger.shared.info(.server, "Server started successfully")

            // Keep Core Location active for the whole server session. On iOS this
            // is required to continue execution and accept TCP traffic while locked.
            locationService.start()

            tcpServer.updateLatest(
                ServerResponsePayload(
                    status: .awaitingLocation,
                    satellites: LocationService.unavailableSatelliteCount,
                    location: nil
                ),
                broadcast: true
            )
            LiveActivityService.shared.start(clientCount: connectedClientCount)
            startAddressRefresh()
        } catch {
            errorText = error.localizedDescription
            statusText = "Ошибка запуска"
            AppLogger.shared.error(.server, "Server start failed: \(error.localizedDescription)")
        }
    }

    func stop() {
        guard isRunning else { return }

        AppLogger.shared.info(.server, "Server stop requested")
        tcpServer.updateLatest(
            ServerResponsePayload(
                status: .locationStopped,
                satellites: LocationService.unavailableSatelliteCount,
                location: nil
            ),
            broadcast: true
        )
        tcpServer.stop()
        locationService.stop()
        LiveActivityService.shared.stop()
        addressRefreshTask?.cancel()
        addressRefreshTask = nil

        isRunning = false
        connectedClientCount = 0
        statusText = "Остановлен"
        refreshLocalIPAddresses()
        AppLogger.shared.info(.server, "Server stopped")
    }

    private func handleLocation(_ location: LocationPayload) {
        guard isRunning else { return }
        lastLocation = location
        statusText = "Передача координат"
        AppLogger.shared.debug(.server, "Sending location to clients with accuracy \(location.accuracy)m")

        tcpServer.updateLatest(
            ServerResponsePayload(
                status: .transmittingLocation,
                satellites: LocationService.unavailableSatelliteCount,
                location: location
            ),
            broadcast: true
        )
        LiveActivityService.shared.update(
            status: "Передача геопозиции",
            clientCount: connectedClientCount,
            locationDate: Date(timeIntervalSince1970: TimeInterval(location.timestamp) / 1_000)
        )
    }

    private func updateAuthorization(
        status: CLAuthorizationStatus,
        accuracy: CLAccuracyAuthorization
    ) {
        locationAuthorizationStatus = status
        locationAccuracyAuthorization = accuracy
        locationAuthorizationText = switch status {
        case .notDetermined: "Не запрошено"
        case .restricted: "Ограничено"
        case .denied: "Запрещено"
        case .authorizedAlways: "Всегда"
        case .authorizedWhenInUse: "При использовании"
        @unknown default: "Неизвестно"
        }

        shouldShowLocationPermissionButton = status != .authorizedAlways
        precisionText = accuracy == .fullAccuracy ? "Точная" : "Приблизительная"
    }

    private func refreshLocalIPAddresses() {
        let addresses = NetworkAddressProvider.localIPv4Addresses()
        if addresses != localIPAddresses {
            AppLogger.shared.info(
                .network,
                "Local IP addresses changed: \(addresses.isEmpty ? "none" : addresses.joined(separator: ", "))"
            )
        }
        localIPAddresses = addresses
    }

    private func startAddressRefresh() {
        addressRefreshTask?.cancel()
        addressRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.refreshLocalIPAddresses()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
}
