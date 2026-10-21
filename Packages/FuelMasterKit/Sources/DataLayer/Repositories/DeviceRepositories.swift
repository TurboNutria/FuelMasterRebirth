import CoreLocation
import DomainLayer
import Foundation
import NetworkLayer

/// Network reachability for the offline pill.
public struct NetworkConnectivityRepository: ConnectivityRepository {
    private let monitor: ConnectivityMonitor

    public init(monitor: ConnectivityMonitor = ConnectivityMonitor()) {
        self.monitor = monitor
    }

    public func updates() async -> AsyncStream<Connectivity> {
        let source = monitor.updates()
        return AsyncStream { continuation in
            let task = Task {
                for await online in source { continuation.yield(online ? .online : .offline) }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// The user's location through Core Location's async APIs (when-in-use only).
public struct LocationRepository: UserLocationRepository {
    public init() {}

    public func authorization() async -> LocationAuthorization {
        Self.map(CLLocationManager().authorizationStatus)
    }

    public func requestAuthorization() async -> LocationAuthorization {
        let current = await authorization()
        guard current == .notDetermined else { return current }
        #if os(iOS)
        // Holding a service session asks for when-in-use permission; wait until the prompt is answered.
        let session = CLServiceSession(authorization: .whenInUse)
        do {
            for try await diagnostic in session.diagnostics where !diagnostic.authorizationRequestInProgress {
                break
            }
        } catch {}
        session.invalidate()
        #endif
        return await authorization()
    }

    public func updates() async -> AsyncStream<Coordinate> {
        AsyncStream { continuation in
            let task = Task {
                #if os(iOS)
                let session = CLServiceSession(authorization: .whenInUse)
                defer { session.invalidate() }
                #endif
                do {
                    for try await update in CLLocationUpdate.liveUpdates() {
                        if let location = update.location {
                            continuation.yield(Coordinate(latitude: location.coordinate.latitude,
                                                          longitude: location.coordinate.longitude))
                        }
                    }
                } catch {}
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static func map(_ status: CLAuthorizationStatus) -> LocationAuthorization {
        switch status {
        case .notDetermined: .notDetermined
        case .authorizedAlways, .authorizedWhenInUse: .authorized
        default: .denied
        }
    }
}
