import BackgroundTasks
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
    #if DEBUG
    @State private var widgetGallery: (WidgetContent, WidgetContent)?
    #endif
    /// Created once so navigation and selection survive layout changes (Bear note 02).
    @State private var router = AppRouter(selectedTab: Self.initialTab)
    @Environment(\.scenePhase) private var scenePhase

    /// The hourly background refresh (Bear note 06, "Background and widgets"). Also listed in
    /// Info.plist's BGTaskSchedulerPermittedIdentifiers.
    nonisolated static let refreshTaskID = "com.turbonutria.fuelmasterrebirth.refresh"

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
                #if DEBUG
                if let widgetGallery {
                    WidgetGalleryScreen(content: widgetGallery.0, stale: widgetGallery.1)
                } else if let models {
                    RootView(router: router, models: models)
                } else if let startupError {
                    ContentUnavailableView("No se pudo abrir la base de datos", systemImage: "exclamationmark.triangle",
                                           description: Text(startupError))
                } else {
                    ProgressView()
                }
                #else
                if let models {
                    RootView(router: router, models: models)
                } else if let startupError {
                    ContentUnavailableView("No se pudo abrir la base de datos", systemImage: "exclamationmark.triangle",
                                           description: Text(startupError))
                } else {
                    ProgressView()
                }
                #endif
            }
            .onOpenURL { router.open($0) }
            .task {
                guard dependencies == nil else { return }
                do {
                    let dependencies = try AppDependencies.shared.get()
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
                    // `-FMWidgetGallery YES` shows the widgets drawn from the cache, fresh and 3 h later.
                    if UserDefaults.standard.bool(forKey: "FMWidgetGallery") {
                        let snapshot = await dependencies.getWidgetSnapshot()
                        widgetGallery = (WidgetContent(snapshot, at: .now),
                                         WidgetContent(snapshot, at: .now.addingTimeInterval(3 * 60 * 60)))
                    }
                    #endif
                    self.models = models
                    await dependencies.reloadWidgetsOnChanges()
                } catch {
                    startupError = error.localizedDescription
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { Self.scheduleRefresh() }
        }
        .backgroundTask(.appRefresh(Self.refreshTaskID)) {
            Self.scheduleRefresh()
            guard let dependencies = try? await AppDependencies.shared.get() else { return }
            await dependencies.refreshInBackground()
        }
    }

    /// Asks iOS for a run in about an hour; it decides when, or whether, it happens.
    nonisolated static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        request.earliestBeginDate = .now.addingTimeInterval(60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
