import DataLayer
import DomainLayer
import Foundation
import SwiftUI
import WatchViewLayer

/// The watch app (Bear note 06, "Apple Watch").
@main
struct FuelMasterWatchApp: App {
    @State private var models: WatchRootModels?

    /// DEBUG: `-FMWatchPage favorites`, `-FMWatchStation 3213` (pushes its detail on that page)
    /// `-FMWatchFuelPicker YES` and `-FMWatchScrollToBottom YES` open the app there, for
    /// simulator screenshots.
    private static var launchState: WatchLaunchState {
        #if DEBUG
        let defaults = UserDefaults.standard
        return WatchLaunchState(page: defaults.string(forKey: "FMWatchPage") == "favorites" ? .favorites : .nearby,
                                station: defaults.string(forKey: "FMWatchStation").map(StationID.init),
                                showsFuelPicker: defaults.bool(forKey: "FMWatchFuelPicker"),
                                scrollsToBottom: defaults.bool(forKey: "FMWatchScrollToBottom"))
        #else
        WatchLaunchState()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let models {
                    WatchRootView(models: models, launch: Self.launchState)
                } else {
                    Color.clear
                }
            }
            .task {
                guard models == nil, let dependencies = try? WatchDependencies.shared.get() else { return }
                #if DEBUG
                await Self.applyLaunchArguments(to: dependencies.mirror)
                #endif
                models = dependencies.makeModels()
                // No onboarding on the watch: ask for location on first launch.
                _ = await dependencies.locateUser.authorize()
                // Keeps the iPhone's fuel, look and favourites in step while the app is open.
                await dependencies.mirror.run()
            }
        }
    }

    #if DEBUG
    /// `-FMWatchFavorite 4710` adds a Madrid station as a favourite, `-FMWatchUnfavorite 4710`
    /// removes it, and `-FMWatchFuel 1` picks a fuel by ministry ID. They go to the iPhone like a
    /// change made on the watch, for sync checks.
    private static func applyLaunchArguments(to mirror: CompanionMirrorRepository) async {
        if let id = UserDefaults.standard.string(forKey: "FMWatchFavorite") {
            try? await mirror.add(StationID(id), province: ProvinceID("28"))
        }
        if let id = UserDefaults.standard.string(forKey: "FMWatchUnfavorite") {
            try? await mirror.remove(StationID(id))
        }
        if let fuel = UserDefaults.standard.object(forKey: "FMWatchFuel") as? String,
           let product = Int(fuel).flatMap(Product.init(rawValue:)) {
            await mirror.update { $0.product = product }
        }
    }
    #endif
}
