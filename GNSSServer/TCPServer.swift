import Foundation
import Network

final class TCPServer {
    var onClientCountChange: ((Int) -> Void)?
    var onFailure: ((Error) -> Void)?

    private let port: NWEndpoint.Port = 8887
    private let queue = DispatchQueue(label: "gnss.server.tcp")
    private var listener: NWListener?
    private var clients: [UUID: ClientSession] = [:]
    private var latestResponse = (
        data: ProtocolCodec.frame(
            ServerResponsePayload(
                status: .uninitialized,
                satellites: LocationService.unavailableSatelliteCount,
                location: nil
            )
        ),
        hasLocation: false
    )

    func start() throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true

        let listener = try NWListener(using: parameters, on: port)
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            if case let .failed(error) = state {
                self.onFailure?(error)
                self.stop()
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        self.listener = listener
        listener.start(queue: queue)
    }

    func updateLatest(_ response: ServerResponsePayload, broadcast: Bool) {
        let framed = ProtocolCodec.frame(response)
        queue.async { [weak self] in
            guard let self else { return }
            self.latestResponse = (framed, response.location != nil)
            if broadcast {
                for client in self.clients.values {
                    client.send(framed)
                }
            }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.listener?.cancel()
            self.listener = nil
            let sessions = Array(self.clients.values)
            self.clients.removeAll()
            sessions.forEach { $0.cancel() }
            self.onClientCountChange?(0)
        }
    }

    private func accept(_ connection: NWConnection) {
        let session = ClientSession(connection: connection)
        session.latestResponse = { [weak self] in
            self?.latestResponse ?? (Data(), false)
        }
        session.onDisconnect = { [weak self] id in
            self?.queue.async {
                guard let self else { return }
                self.clients.removeValue(forKey: id)
                self.onClientCountChange?(self.clients.count)
            }
        }
        clients[session.id] = session
        onClientCountChange?(clients.count)
        session.start()
    }
}

