import Foundation
import Network

final class ClientSession {
    private static let heartbeatPackets: Set<UInt8> = [0x01, 0x02]
    private static let heartbeatTimeout: TimeInterval = 3
    private static let responseInterval: TimeInterval = 1

    let id = UUID()

    var onDisconnect: ((UUID) -> Void)?
    var onHeartbeat: ((UUID) -> Void)?
    var onHeartbeatTimeout: ((UUID) -> Void)?
    var onSendSuccess: ((UUID) -> Void)?
    var onSendError: ((UUID, Error) -> Void)?
    var latestResponse: (() -> (data: Data, hasLocation: Bool))?

    private let connection: NWConnection
    private let queue: DispatchQueue
    private var heartbeatTimer: DispatchSourceTimer?
    private var lastHeartbeat = Date()
    private var lastResponse = Date.distantPast
    private var disconnected = false

    init(connection: NWConnection) {
        self.connection = connection
        queue = DispatchQueue(label: "gnss.server.client.\(id.uuidString)")
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                AppLogger.shared.info(.client, "Client \(self.id) connection ready")
                self.sendLatestResponse()
                self.startHeartbeatTimer()
                self.receiveHeartbeat()
            case let .failed(error):
                AppLogger.shared.warn(.client, "Client \(self.id) connection failed: \(error.localizedDescription)")
                self.disconnect()
            case .cancelled:
                self.disconnect()
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    func send(_ data: Data) {
        queue.async { [weak self] in
            self?.sendOnQueue(data)
        }
    }

    func cancel() {
        queue.async { [weak self] in
            self?.disconnect()
        }
    }

    private func receiveHeartbeat() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            if let byte = data?.first, Self.heartbeatPackets.contains(byte) {
                self.lastHeartbeat = Date()
                self.onHeartbeat?(self.id)
                let latest = self.latestResponse?()
                if self.lastResponse.timeIntervalSinceNow < -Self.responseInterval
                    || latest?.hasLocation == false {
                    self.sendLatestResponse()
                }
            }

            if isComplete || error != nil {
                self.disconnect()
            } else {
                self.receiveHeartbeat()
            }
        }
    }

    private func sendLatestResponse() {
        guard let response = latestResponse?() else { return }
        sendOnQueue(response.data)
    }

    private func sendOnQueue(_ data: Data) {
        guard !disconnected else { return }
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            guard let self else { return }
            if error != nil {
                self.onSendError?(self.id, error!)
                self.disconnect()
            } else {
                self.lastResponse = Date()
                self.onSendSuccess?(self.id)
            }
        })
    }

    private func startHeartbeatTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            if Date().timeIntervalSince(self.lastHeartbeat) > Self.heartbeatTimeout {
                self.onHeartbeatTimeout?(self.id)
                self.disconnect()
            }
        }
        heartbeatTimer = timer
        timer.resume()
    }

    private func disconnect() {
        guard !disconnected else { return }
        disconnected = true
        heartbeatTimer?.cancel()
        heartbeatTimer = nil
        connection.cancel()
        AppLogger.shared.info(.client, "Client \(id) disconnected")
        onDisconnect?(id)
    }
}
