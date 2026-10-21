import Foundation
import Network

/// Reports whether the device has a usable network path.
public struct ConnectivityMonitor: Sendable {
    public init() {}

    /// Emits `true` when online and `false` when offline, starting with the current state.
    /// Each call gets its own path monitor, cancelled when the stream ends.
    public func updates() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                continuation.yield(path.status == .satisfied)
            }
            continuation.onTermination = { _ in monitor.cancel() }
            monitor.start(queue: DispatchQueue(label: "FuelMaster.ConnectivityMonitor"))
        }
    }
}
