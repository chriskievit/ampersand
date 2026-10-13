import Foundation
import Network
import Synchronization
import Testing
@testable import AmpersandCore

/// Local TCP server; when `response` is set it answers every request with it.
final class TestServer: Sendable {
    let listener: NWListener
    var port: Int { Int(listener.port!.rawValue) }

    init(response: String?) async throws {
        let listener = try NWListener(using: .tcp, on: .any)
        self.listener = listener
        listener.newConnectionHandler = { connection in
            connection.start(queue: .global())
            guard let response else { return }
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { _, _, _, _ in
                connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
            }
        }
        let ready = Mutex(false)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            listener.stateUpdateHandler = { state in
                if case .ready = state, ready.withLock({ let first = !$0; $0 = true; return first }) {
                    continuation.resume()
                }
            }
            listener.start(queue: .global())
        }
    }

    func stop() { listener.cancel() }
}

@Suite(.serialized) struct HealthCheckerTests {
    @Test func tcpHealthyWhenListening() async throws {
        let server = try await TestServer(response: nil)
        #expect(await HealthChecker.check(.tcp, port: server.port) == .healthy)
        server.stop()
    }

    @Test func tcpUnhealthyWhenClosed() async throws {
        let server = try await TestServer(response: nil)
        let port = server.port
        server.stop()
        try await Task.sleep(for: .milliseconds(100))
        let result = await HealthChecker.check(.tcp, port: port)
        #expect(result != .healthy)
    }

    @Test func tcpWithoutPort() async {
        #expect(await HealthChecker.check(.tcp, port: nil) == .unhealthy("No port set"))
    }

    @Test func http404CountsAsUp() async throws {
        let server = try await TestServer(response: "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
        #expect(await HealthChecker.check(.http(url: "http://localhost:\(server.port)/health"), port: nil) == .healthy)
        server.stop()
    }

    @Test func http502IsUnhealthy() async throws {
        let server = try await TestServer(response: "HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
        #expect(await HealthChecker.check(.http(url: "http://localhost:\(server.port)/"), port: nil) == .unhealthy("HTTP 502"))
        server.stop()
    }

    @Test func invalidURL() async {
        #expect(await HealthChecker.check(.http(url: "not a url"), port: nil) == .unhealthy("Invalid URL"))
    }
}
