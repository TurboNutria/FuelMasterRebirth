import Foundation

/// Online / offline for the red pill.
public struct ObserveConnectivity: Sendable {
    private let connectivity: any ConnectivityRepository

    public init(connectivity: any ConnectivityRepository) {
        self.connectivity = connectivity
    }

    public func callAsFunction() async -> AsyncStream<Connectivity> {
        await connectivity.updates()
    }
}

/// Where the user is, for the list and the map. Asks for when-in-use permission the first time.
/// Not in note 07's first list: added in U2 so view models don't reach the repository directly.
public struct LocateUser: Sendable {
    private let location: any UserLocationRepository
    private let firstFixTimeout: Duration

    public init(location: any UserLocationRepository, firstFixTimeout: Duration = .seconds(6)) {
        self.location = location
        self.firstFixTimeout = firstFixTimeout
    }

    /// Asks for permission if it hasn't been asked yet, and reports the answer.
    public func authorize() async -> LocationAuthorization {
        await location.requestAuthorization()
    }

    public func updates() async -> AsyncStream<Coordinate> {
        await location.updates()
    }

    /// The first fix, or nil if none arrives in time (indoors, a simulator without a location).
    /// Screens keep listening to `updates()`, so a late fix still moves them.
    public func firstFix() async -> Coordinate? {
        let stream = await location.updates()
        let timeout = firstFixTimeout
        return await withTaskGroup(of: Coordinate?.self) { group in
            group.addTask {
                for await coordinate in stream { return coordinate }
                return nil
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}
