import Foundation
import Network
import Synchronization

public enum HealthResult: Sendable, Equatable {
    case healthy
    case unhealthy(String)
}

/// Reports whether a command's service answers. Never acts on the result.
public enum HealthChecker {
    public static func check(_ check: HealthCheck, port: Int?, timeout: Duration = .seconds(2)) async -> HealthResult {
        switch check {
        case .tcp:
            guard let port, let endpointPort = NWEndpoint.Port(rawValue: UInt16(clamping: port)) else {
                return .unhealthy("No port set")
            }
            return await tcp(port: endpointPort, timeout: timeout)
        case .http(let url):
            return await http(url, timeout: timeout)
        }
    }

    private static let session = URLSession(configuration: .ephemeral)

    private static func seconds(_ d: Duration) -> Double {
        Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18
    }

    private static func tcp(port: NWEndpoint.Port, timeout: Duration) async -> HealthResult {
        let connection = NWConnection(host: "localhost", port: port, using: .tcp)
        let finished = Mutex(false)
        return await withCheckedContinuation { continuation in
            let finish: @Sendable (HealthResult) -> Void = { result in
                guard finished.withLock({ let first = !$0; $0 = true; return first }) else { return }
                connection.cancel()
                continuation.resume(returning: result)
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: finish(.healthy)
                case .failed, .waiting: finish(.unhealthy("Port \(port.rawValue) refused the connection"))
                default: break
                }
            }
            connection.start(queue: .global())
            let limit = seconds(timeout)
            DispatchQueue.global().asyncAfter(deadline: .now() + limit) {
                finish(.unhealthy("Port \(port.rawValue) did not answer within \(Int(limit)) s"))
            }
        }
    }

    private static func http(_ urlString: String, timeout: Duration) async -> HealthResult {
        guard let url = URL(string: urlString), let scheme = url.scheme, ["http", "https"].contains(scheme),
              url.host != nil else {
            return .unhealthy("Invalid URL")
        }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: seconds(timeout))
        do {
            let (_, response) = try await session.data(for: request)
            guard let code = (response as? HTTPURLResponse)?.statusCode else { return .unhealthy("No HTTP response") }
            return (200..<500).contains(code) ? .healthy : .unhealthy("HTTP \(code)")
        } catch {
            return .unhealthy(error.localizedDescription)
        }
    }
}
