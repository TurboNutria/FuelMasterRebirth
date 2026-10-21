import Foundation

public struct RefreshOutcome: Sendable, Equatable {
    public var updated: [ProvinceID] = []
    public var skipped: [ProvinceID] = []
    public var failed: [ProvinceID: DomainError] = [:]

    public init() {}

    public var isOffline: Bool { !failed.isEmpty && failed.values.allSatisfy { $0 == .offline } }
}

/// Refreshes the provinces whose prices are older than 30 minutes, saves them and reloads widgets.
public struct RefreshPrices: Sendable {
    private let remote: any StationRemoteRepository
    private let cache: any StationCacheRepository
    private let widgets: (any WidgetRefreshing)?
    private let now: @Sendable () -> Date

    public init(remote: any StationRemoteRepository, cache: any StationCacheRepository,
                widgets: (any WidgetRefreshing)? = nil, now: @escaping @Sendable () -> Date = { .now }) {
        self.remote = remote
        self.cache = cache
        self.widgets = widgets
        self.now = now
    }

    public func callAsFunction(_ provinces: [ProvinceID], force: Bool = false) async -> RefreshOutcome {
        var outcome = RefreshOutcome()
        var toFetch: [ProvinceID] = []
        for province in Set(provinces).sorted() {
            let freshness = try? await cache.freshness(of: province)
            if force || freshness == nil || freshness!.isStale(at: now()) {
                toFetch.append(province)
            } else {
                outcome.skipped.append(province)
            }
        }

        // A few provinces at a time keeps the ministry's server happy.
        let results = await withTaskGroup(of: (ProvinceID, Result<ProvinceSnapshot, DomainError>).self) { group in
            var collected: [(ProvinceID, Result<ProvinceSnapshot, DomainError>)] = []
            var iterator = toFetch.makeIterator()
            for _ in 0..<3 {
                guard let next = iterator.next() else { break }
                group.addTask { await (next, fetch(next)) }
            }
            while let result = await group.next() {
                collected.append(result)
                if let next = iterator.next() { group.addTask { await (next, fetch(next)) } }
            }
            return collected
        }

        for (province, result) in results {
            switch result {
            case .success(let snapshot):
                do {
                    try await cache.save(snapshot, fetchedAt: now())
                    outcome.updated.append(province)
                } catch {
                    outcome.failed[province] = .unreadableResponse
                }
            case .failure(let error):
                outcome.failed[province] = error
            }
        }
        outcome.updated.sort()
        if !outcome.updated.isEmpty { widgets?.reloadAll() }
        return outcome
    }

    private func fetch(_ province: ProvinceID) async -> Result<ProvinceSnapshot, DomainError> {
        do {
            return .success(try await remote.currentPrices(province: province))
        } catch let error as DomainError {
            return .failure(error)
        } catch {
            return .failure(.serverUnavailable)
        }
    }
}
