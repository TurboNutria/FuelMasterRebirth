import SwiftUI
import ViewLayer
import ViewModelLayer

@main
struct FuelMasterApp: App {
    @State private var dependencies: AppDependencies?
    @State private var stationList: StationListViewModel?
    @State private var map: MapViewModel?
    @State private var startupError: String?
    /// Created once so navigation and selection survive layout changes (Bear note 02).
    @State private var router = AppRouter(selectedTab: Self.initialTab)

    /// DEBUG: `-FMInitialTab list` opens a tab at launch, for simulator screenshots.
    private static var initialTab: AppTab {
        #if DEBUG
        UserDefaults.standard.string(forKey: "FMInitialTab").flatMap(AppTab.init(rawValue:)) ?? .map
        #else
        .map
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let stationList, let map {
                    RootView(router: router, stationList: stationList, map: map)
                } else if let startupError {
                    ContentUnavailableView("No se pudo abrir la base de datos", systemImage: "exclamationmark.triangle",
                                           description: Text(startupError))
                } else {
                    ProgressView()
                }
            }
            .task {
                guard dependencies == nil else { return }
                do {
                    let dependencies = try AppDependencies()
                    self.dependencies = dependencies
                    stationList = dependencies.makeStationListViewModel()
                    map = dependencies.makeMapViewModel()
                } catch {
                    startupError = error.localizedDescription
                }
            }
        }
    }
}
