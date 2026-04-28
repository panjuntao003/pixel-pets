import Foundation
import Network

final class HookServer {
    static let port: UInt16 = 15799

    var onEvent: ((String, [String: Any]) -> Void)?

    private var listener: NWListener?

    func start() {
        let params = NWParameters.tcp
        params.acceptLocalOnly = true

        guard let port = NWEndpoint.Port(rawValue: Self.port) else {
            return
        }

        listener = try? NWListener(using: params, on: port)
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener?.start(queue: .global(qos: .utility))
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .utility))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, _ in
            if let data, let raw = String(data: data, encoding: .utf8),
               let bodyStart = raw.range(of: "\r\n\r\n") {
                let body = String(raw[bodyStart.upperBound...])
                if let jsonData = body.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let event = json["event"] as? String {
                    DispatchQueue.main.async {
                        self?.onEvent?(event, json)
                    }
                }
            }

            Self.sendOK(on: connection)
        }
    }

    private static func sendOK(on connection: NWConnection) {
        let response = "HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
