import DataLayer
import DomainLayer
import SwiftUI
import ViewLayer
import ViewModelLayer

@main
struct FuelMasterApp: App {
    @State private var dependencies: AppDependencies?
    @State private var models: RootViewModels?
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
                if let models {
                    RootView(router: router, models: models)
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
                    let models = dependencies.makeViewModels()
                    #if DEBUG
                    // `-FMSkipOnboarding YES` marks onboarding done, for screenshots of the other screens.
                    if UserDefaults.standard.bool(forKey: "FMSkipOnboarding") {
                        await dependencies.updateSettings { $0.onboardingCompleted = true }
                    }
                    // `-FMSelectStation <IDEESS>` opens a station's detail at launch, for screenshots.
                    if let id = UserDefaults.standard.string(forKey: "FMSelectStation") {
                        router.select(StationID(id))
                    }
                    // `-FMSearch repsol` types into Buscar.
                    if let text = UserDefaults.standard.string(forKey: "FMSearch") { models.search.text = text }
                    // `-FMSeedFavorites 3213,2909` makes those Madrid stations favourites, in that order.
                    if let ids = UserDefaults.standard.string(forKey: "FMSeedFavorites") {
                        for id in ids.split(separator: ",") {
                            try? await dependencies.favorites.add(StationID(String(id)), province: ProvinceID("28"))
                        }
                    }
                    #endif
                    self.models = models
                } catch {
                    startupError = error.localizedDescription
                }
            }
        }
    }
}
