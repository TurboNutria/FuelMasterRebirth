import DomainLayer
import Foundation
import SwiftData
// iCLOUD: uncomment once the paid Apple Developer account and the iCloud capability are set up.
// import CloudKit

/// Favourites in SwiftData. The model is already CloudKit-shaped (see FavoriteModels.swift), so
/// enabling sync later is: the iCloud + Background Modes capabilities, the container configuration in
/// `PersistenceFactory.favoritesContainer`, and the account-status code below.
public final class FavoritesRepository: FavoriteStationsRepository {
    private let store: FavoritesStore
    private let broadcaster = Broadcaster<[FavoriteEntry]>()

    public init(container: ModelContainer) {
        store = FavoritesStore(modelContainer: container)
    }

    public func favorites() async throws -> [FavoriteEntry] {
        try await store.entries()
    }

    public func add(_ station: StationID, province: ProvinceID) async throws {
        try await store.add(station, province: province)
        await publish()
    }

    public func remove(_ station: StationID) async throws {
        try await store.remove(station)
        await publish()
    }

    public func move(from source: Int, to destination: Int) async throws {
        try await store.move(from: source, to: destination)
        await publish()
    }

    public func changes() async -> AsyncStream<[FavoriteEntry]> {
        // iCLOUD: also re-publish when CloudKit merges changes from another device, by observing
        // `NSPersistentStoreRemoteChange` notifications and calling `publish()`.
        await broadcaster.stream()
    }

    public func iCloudStatus() async -> AsyncStream<ICloudStatus> {
        AsyncStream { continuation in
            continuation.yield(.syncDisabled)
            continuation.finish()
            // iCLOUD: replace the two lines above with the account status, re-checked on
            // `.CKAccountChanged` notifications:
            //
            // Task {
            //     let status = try? await CKContainer(identifier: PersistenceFactory.cloudKitContainer).accountStatus()
            //     continuation.yield(Self.map(status))
            // }
        }
    }

    // iCLOUD:
    // static func map(_ status: CKAccountStatus?) -> ICloudStatus {
    //     switch status {
    //     case .available: .available
    //     case .noAccount: .noAccount
    //     case .restricted: .restricted
    //     default: .temporarilyUnavailable
    //     }
    // }

    private func publish() async {
        if let entries = try? await store.entries() { await broadcaster.send(entries) }
    }
}

@ModelActor
actor FavoritesStore {
    /// Ordered favourites, with duplicates (the same station from two devices) removed.
    func entries() throws -> [FavoriteEntry] {
        let all = try modelContext.fetch(FetchDescriptor<FavoriteStation>(sortBy: [SortDescriptor(\.order), SortDescriptor(\.addedAt)]))
        var seen = Set<String>()
        var unique: [FavoriteStation] = []
        for favorite in all {
            if seen.insert(favorite.stationID).inserted {
                unique.append(favorite)
            } else {
                modelContext.delete(favorite)
            }
        }
        if unique.count != all.count { try modelContext.save() }
        return unique.enumerated().map { index, favorite in
            FavoriteEntry(stationID: StationID(favorite.stationID), provinceID: ProvinceID(favorite.provinceID), order: index)
        }
    }

    func add(_ station: StationID, province: ProvinceID) throws {
        let current = try entries()
        guard !current.contains(where: { $0.stationID == station }) else { return }
        modelContext.insert(FavoriteStation(stationID: station.rawValue, provinceID: province.rawValue, order: current.count))
        try modelContext.save()
    }

    func remove(_ station: StationID) throws {
        let raw = station.rawValue
        try modelContext.delete(model: FavoriteStation.self, where: #Predicate { $0.stationID == raw })
        try modelContext.save()
    }

    func move(from source: Int, to destination: Int) throws {
        var all = try modelContext.fetch(FetchDescriptor<FavoriteStation>(sortBy: [SortDescriptor(\.order), SortDescriptor(\.addedAt)]))
        guard all.indices.contains(source) else { return }
        let item = all.remove(at: source)
        all.insert(item, at: min(max(0, destination), all.count))
        for (index, favorite) in all.enumerated() { favorite.order = index }
        try modelContext.save()
    }
}
