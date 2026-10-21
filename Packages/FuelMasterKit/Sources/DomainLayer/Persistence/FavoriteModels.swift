import Foundation
import SwiftData

// Favourites are shaped for CloudKit from day one: every property has a default and there are
// no unique constraints, so turning iCloud sync on later needs no migration.
// Duplicates (the same station added on two devices) are removed by FavoritesRepository.

@Model
public final class FavoriteStation {
    public var stationID: String = ""
    public var provinceID: String = ""
    public var order: Int = 0
    public var addedAt: Date = Date.now

    public init(stationID: String, provinceID: String, order: Int, addedAt: Date = .now) {
        self.stationID = stationID
        self.provinceID = provinceID
        self.order = order
        self.addedAt = addedAt
    }
}

public enum FavoritesSchema {
    public static let models: [any PersistentModel.Type] = [FavoriteStation.self]
}
