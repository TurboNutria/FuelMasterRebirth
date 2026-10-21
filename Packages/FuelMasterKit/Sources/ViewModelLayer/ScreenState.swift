import DomainLayer
import Foundation

/// What every screen can be showing (Bear note 07, section 5).
public enum ScreenState<Content: Sendable & Equatable>: Sendable, Equatable {
    /// Nothing cached yet: spinner on lists, grey "---" pins on the map.
    case firstLoad
    case content(Content)
    /// Cached content is visible while new prices load ("Actualizando…").
    case updating(Content)
    /// Network lost: cached content plus its age for the red pill.
    case offline(Content, age: TimeInterval?)
    case empty(EmptyReason)
    case failed(DomainError)

    public var content: Content? {
        switch self {
        case .content(let content), .updating(let content), .offline(let content, _): content
        case .firstLoad, .empty, .failed: nil
        }
    }
}

public enum EmptyReason: Sendable, Equatable {
    case noStationsNearby(Product)
    case noFavorites
    case noSearchResults(String)
}
