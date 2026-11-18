import Foundation

public enum SearchScope: String, CaseIterable, Sendable {
    /// Digits search postcodes; anything else, brands nearby plus localities anywhere.
    case all, brand, locality, postcode
}

public struct SearchQuery: Hashable, Sendable {
    public let text: String
    public let scope: SearchScope

    public init(text: String, scope: SearchScope) {
        self.text = text
        self.scope = scope
    }
}

public enum Connectivity: Sendable, Equatable {
    case online
    case offline
}

public enum ICloudStatus: Sendable, Equatable {
    case available
    case noAccount
    case restricted
    case temporarilyUnavailable
    /// iCloud sync is switched off in this build (no paid developer account yet).
    case syncDisabled
}

public enum DomainError: Error, Sendable, Equatable {
    case offline
    case serverUnavailable
    case unreadableResponse
    case notFound
}
