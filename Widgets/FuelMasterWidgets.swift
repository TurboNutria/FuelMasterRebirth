import DataLayer
import DomainLayer
import SwiftUI
import ViewModelLayer
import WidgetKit
import WidgetViewLayer

@main
struct FuelMasterWidgets: WidgetBundle {
    var body: some Widget {
        CheapestNearbyWidget()
        FavoritesWidget()
    }
}

/// Small Home Screen widget and the three Lock Screen ones: the cheapest station nearby.
struct CheapestNearbyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CheapestNearby", provider: SnapshotProvider()) { entry in
            CheapestNearbyEntryView(content: entry.content)
        }
        .configurationDisplayName(Text(WidgetNames.cheapest))
        .supportedFamilies([.systemSmall, .accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

private struct CheapestNearbyEntryView: View {
    let content: WidgetContent
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryInline: InlineWidgetView(content: content)
        case .accessoryCircular: CircularWidgetView(content: content)
        case .accessoryRectangular: RectangularWidgetView(content: content)
        default: CheapestWidgetView(content: content)
        }
    }
}

/// Medium Home Screen widget: the first three favourites.
struct FavoritesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Favorites", provider: SnapshotProvider()) { entry in
            FavoritesWidgetView(content: entry.content)
        }
        .configurationDisplayName(Text(WidgetNames.favorites))
        .supportedFamilies([.systemMedium])
    }
}

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let content: WidgetContent
}

/// Reads the shared cache only; the app and its background refresh fetch prices and reload the
/// timelines. A second entry dims the prices once they turn an hour old.
struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, content: .sample)
    }

    /// The gallery shows the user's own prices when the cache has them, else the sample.
    func getSnapshot(in context: Context, completion: @escaping @Sendable (SnapshotEntry) -> Void) {
        Task {
            let content = await WidgetData.snapshot().map { WidgetContent($0, at: .now) }
            completion(SnapshotEntry(date: .now, content: content?.cheapest == nil ? .sample : content!))
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<SnapshotEntry>) -> Void) {
        Task {
            let now = Date.now
            guard let snapshot = await WidgetData.snapshot() else {
                completion(Timeline(entries: [SnapshotEntry(date: now, content: .sample)], policy: .after(now + 30 * 60)))
                return
            }
            var entries = [SnapshotEntry(date: now, content: WidgetContent(snapshot, at: now))]
            if let stale = WidgetContent.staleDate(of: snapshot), stale > now {
                entries.append(SnapshotEntry(date: stale, content: WidgetContent(snapshot, at: stale)))
            }
            // Re-read the cache now and then, in case a reload from the app was missed.
            completion(Timeline(entries: entries, policy: .after(now + 30 * 60)))
        }
    }
}

/// The widget's own composition root: the same stores as the app, through the App Group.
enum WidgetData {
    static func snapshot() async -> WidgetSnapshot? {
        guard let cacheContainer = try? PersistenceFactory.cacheContainer(),
              let favoritesContainer = try? PersistenceFactory.favoritesContainer() else { return nil }
        let local = LocalDataRepository(container: cacheContainer, defaults: PersistenceFactory.sharedDefaults())
        let favorites = FavoritesRepository(container: favoritesContainer)
        let use = GetWidgetSnapshot(
            settings: local, provinces: local,
            nearby: ObserveNearbyStations(cache: local, favorites: favorites),
            favorites: ObserveFavorites(favorites: favorites, cache: local)
        )
        return await use()
    }
}
