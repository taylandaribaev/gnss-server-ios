import Foundation
import Network

/// Answers GNSS Share UDP discovery. A client that doesn't know the server's address sends
/// `GNSS_SHARE_DISCOVERY_PROBE_1` to UDP port 8887 (first to the broadcast addresses, then to every address in
/// its /24) and uses the source address of the `GNSS_SHARE_DISCOVERY_REPLY_1` reply as the server's address.
/// The responder only answers, it never announces itself.
///
/// Broadcast probes don't reach the app, because iOS only delivers broadcast packets to apps with the multicast
/// networking entitlement. The client's unicast sweep does, and the client runs it on /24 or smaller networks.
/// On the iPhone's own hotspot no answer is needed, since the client tries its gateway, which is the iPhone.
/// On bigger networks the address has to be typed into the client.
final class DiscoveryResponder {
    /// Discovery port. Same number as the TCP port, but a separate constant in the protocol too.
    private static let port: NWEndpoint.Port = 8887
    private static let probe = Data("GNSS_SHARE_DISCOVERY_PROBE_1".utf8)
    private static let reply = Data("GNSS_SHARE_DISCOVERY_REPLY_1".utf8)

    /// How long to wait before trying again after the listener failed or couldn't start.
    private static let retryDelay: TimeInterval = 5

    private let queue = DispatchQueue(label: "gnss.server.discovery")
    /// Only touched on the main thread, like `start()` and `stop()`.
    private var listener: NWListener?
    private var wanted = false

    /// Discovery is optional: if the responder can't start, it logs that and tries again, and the server keeps
    /// running without it.
    func start() {
        wanted = true
        listen()
    }

    func stop() {
        wanted = false
        listener?.cancel()
        listener = nil
    }

    private func listen() {
        guard wanted, listener == nil else { return }
        do {
            let parameters = NWParameters.udp
            parameters.allowLocalEndpointReuse = true
            let listener = try NWListener(using: parameters, on: Self.port)
            listener.newConnectionHandler = { [weak self] connection in
                self?.answer(connection)
            }
            listener.stateUpdateHandler = { [weak self, weak listener] state in
                switch state {
                case .ready:
                    AppLogger.shared.info(.server, "Discovery responder listening on UDP \(Self.port)")
                case let .failed(error):
                    AppLogger.shared.warn(.server, "Discovery responder failed: \(error.localizedDescription)")
                    guard let listener else { return }
                    listener.cancel()
                    DispatchQueue.main.async { self?.failed(listener) }
                default:
                    break
                }
            }
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            AppLogger.shared.warn(.server, "Discovery responder could not start: \(error.localizedDescription)")
            retryLater()
        }
    }

    private func failed(_ failedListener: NWListener) {
        guard listener === failedListener else { return }
        listener = nil
        retryLater()
    }

    private func retryLater() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.retryDelay) { [weak self] in
            self?.listen()
        }
    }

    /// Each client gets its own connection. Answer the probe and close it, the client's next discovery uses a
    /// new socket anyway.
    private func answer(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receiveMessage { data, _, _, error in
            guard error == nil, data == Self.probe else {
                connection.cancel()
                return
            }
            connection.send(content: Self.reply, completion: .contentProcessed { _ in
                connection.cancel()
            })
            AppLogger.shared.debug(.server, "Answered a discovery probe from \(connection.endpoint)")
        }
    }
}
