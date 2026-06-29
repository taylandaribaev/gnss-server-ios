import CoreLocation
import Foundation

@MainActor
final class ServerCoordinator: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var connectedClientCount = 0
    @Published private(set) var statusText = "Остановлен"
    @Published private(set) var errorText: String?
    @Published private(set) var lastLocation: LocationPayload?
    @Published private(set) var locationAuthorizationText = "Не запрошено"
    @Published private(set) var precisionText = "Неизвестно"
    @Published private(set) var localIPAddresses: [String] = []

    private let locationService = LocationService()
    private let tcpServer = TCPServer()
    private var addressRefreshTask: Task<Void, Never>?

    init() {
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

    func requestPermissions() {
        locationService.requestAuthorization()
    }

    func start() {
        guard !isRunning else { return }

        errorText = nil
        requestPermissions()

        do {
            try tcpServer.start()
            isRunning = true
            statusText = "Ожидание координат"

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
        }
    }

    func stop() {
        guard isRunning else { return }

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
    }

    private func handleLocation(_ location: LocationPayload) {
        guard isRunning else { return }
        lastLocation = location
        statusText = "Передача координат"

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
        locationAuthorizationText = switch status {
        case .notDetermined: "Не запрошено"
        case .restricted: "Ограничено"
        case .denied: "Запрещено"
        case .authorizedAlways: "Всегда"
        case .authorizedWhenInUse: "При использовании"
        @unknown default: "Неизвестно"
        }

        precisionText = accuracy == .fullAccuracy ? "Точная" : "Приблизительная"
    }

    private func refreshLocalIPAddresses() {
        localIPAddresses = NetworkAddressProvider.localIPv4Addresses()
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
