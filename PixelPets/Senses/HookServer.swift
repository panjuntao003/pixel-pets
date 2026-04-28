import Foundation
import Network

final class HookServer {
    static let port: UInt16 = 15799

    var onEvent: ((String, [String: Any]) -> Void)?
    private(set) var lastError: Error?
    private(set) var isRunning = false

    private var listener: NWListener?
    private static let maxRequestBytes = 65536

    func start() {
        lastError = nil
        isRunning = false

        let params = NWParameters.tcp
        params.acceptLocalOnly = true

        guard let port = NWEndpoint.Port(rawValue: Self.port) else {
            return
        }

        do {
            listener = try NWListener(using: params, on: port)
        } catch {
            lastError = error
            listener = nil
            return
        }

        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.isRunning = true
                self?.lastError = nil
            case .failed(let error):
                self?.isRunning = false
                self?.lastError = error
            case .cancelled:
                self?.isRunning = false
            default:
                break
            }
        }
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener?.start(queue: .global(qos: .utility))
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .utility))
        receiveRequest(on: connection, buffer: Data())
    }

    private func receiveRequest(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            var nextBuffer = buffer
            if let data {
                nextBuffer.append(data)
            }

            if let body = Self.completeBody(in: nextBuffer) {
                self?.dispatchEvent(from: body)
                Self.sendOK(on: connection)
                return
            }

            if isComplete || error != nil || nextBuffer.count >= Self.maxRequestBytes {
                Self.sendOK(on: connection)
                return
            }

            guard let self else {
                Self.sendOK(on: connection)
                return
            }

            self.receiveRequest(on: connection, buffer: nextBuffer)
        }
    }

    private static func sendOK(on connection: NWConnection) {
        let response = "HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private static func completeBody(in requestData: Data) -> Data? {
        let separator = Data("\r\n\r\n".utf8)
        guard let headerRange = requestData.range(of: separator) else {
            return nil
        }

        let headerEnd = headerRange.upperBound
        let headers = String(data: requestData[..<headerRange.lowerBound], encoding: .utf8) ?? ""
        let contentLength = contentLength(in: headers) ?? 0
        guard requestData.count - headerEnd >= contentLength else {
            return nil
        }

        return requestData.subdata(in: headerEnd..<(headerEnd + contentLength))
    }

    private static func contentLength(in headers: String) -> Int? {
        for line in headers.components(separatedBy: "\r\n").dropFirst() {
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else {
                continue
            }

            let name = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard name == "content-length" else {
                continue
            }

            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            return Int(value).flatMap { $0 >= 0 ? $0 : nil }
        }

        return nil
    }

    private func dispatchEvent(from body: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let event = json["event"] as? String else {
            return
        }

        DispatchQueue.main.async {
            self.onEvent?(event, json)
        }
    }
}
