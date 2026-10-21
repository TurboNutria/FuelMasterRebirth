import DomainLayer
import Foundation
import SwiftData

/// Builds the two SwiftData containers. Called once by the App target (the composition root).
public enum PersistenceFactory {
    public static let appGroup = "group.com.turbonutria.FuelMaster"
    public static let cloudKitContainer = "iCloud.com.turbonutria.FuelMaster"

    /// Shared with the widget extension when the App Group is provisioned; otherwise the app's own
    /// Application Support folder (e.g. without a paid developer account).
    public static func storeDirectory() -> URL {
        if let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) {
            return group.appending(path: "Library/Application Support", directoryHint: .isDirectory)
        }
        return URL.applicationSupportDirectory
    }

    public static func sharedDefaults() -> UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    public static func cacheContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(CacheSchema.models)
        let configuration = inMemory
            ? ModelConfiguration("Cache", schema: schema, isStoredInMemoryOnly: true)
            : ModelConfiguration("Cache", schema: schema, url: try storeURL(named: "Cache.store"), cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    public static func favoritesContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(FavoritesSchema.models)
        let configuration = inMemory
            ? ModelConfiguration("Favorites", schema: schema, isStoredInMemoryOnly: true)
            : ModelConfiguration("Favorites", schema: schema, url: try storeURL(named: "Favorites.store"),
                                 cloudKitDatabase: .none)
                // iCLOUD: swap `.none` above for the private database once the capability exists:
                // cloudKitDatabase: .private(cloudKitContainer)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    private static func storeURL(named name: String) throws -> URL {
        let directory = storeDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: name)
    }
}
