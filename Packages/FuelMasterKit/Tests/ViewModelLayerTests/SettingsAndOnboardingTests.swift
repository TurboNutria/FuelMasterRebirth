import DomainLayer
import Foundation
import Testing
import ViewModelLayer

@Suite("Ajustes and onboarding")
@MainActor
struct SettingsAndOnboardingTests {
    func settingsViewModel(_ settings: FakeSettings, cache: FakeCache = FakeCache()) -> SettingsViewModel {
        SettingsViewModel(observeSettings: ObserveSettings(settings: settings), updateSettings: UpdateSettings(settings: settings),
                          resolveProvinces: ResolveProvinces(provinces: FakeProvinces()),
                          getDataSourceInfo: GetDataSourceInfo(cache: cache, provinces: FakeProvinces()))
    }

    func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<200 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test func changesShowAtOnceAndAreSaved() async {
        let store = FakeSettings()
        let viewModel = settingsViewModel(store)
        let task = Task { await viewModel.start() }
        await waitUntil { viewModel.isLoaded && !viewModel.provinces.isEmpty }

        await viewModel.setAccent(.preset(.blue))
        await viewModel.setPriceScale(.blueOrange)
        await viewModel.setAppearance(.dark)
        await viewModel.setDefaultProvince(ProvinceID("28"))
        #expect(viewModel.settings.accent == .preset(.blue))
        #expect(viewModel.defaultProvinceName == "Madrid")
        let saved = await store.settings
        #expect(saved.priceScale == .blueOrange)
        #expect(saved.appearance == .dark)
        task.cancel()
    }

    @Test func tankSizeIsWholeAndWithinRange() async {
        let store = FakeSettings()
        let viewModel = settingsViewModel(store)
        await viewModel.setTankSize(Decimal(string: "55.6")!)
        #expect(viewModel.settings.tankSize == 56)
        await viewModel.setTankSize(400)
        #expect(viewModel.settings.tankSize == 150)
        await viewModel.stepTankSize(by: 1)
        #expect(viewModel.settings.tankSize == 150)
        await viewModel.setTankSize(5)
        await viewModel.stepTankSize(by: -1)
        #expect(await store.settings.tankSize == 4)
        await viewModel.setTankSize(0)
        #expect(await store.settings.tankSize == 1)
    }

    @Test func dataSourceUsesTheNewestCachedProvince() async {
        let date = ListHarness.now.addingTimeInterval(-12 * 60)
        let cache = FakeCache(freshness: [ProvinceID("28"): Freshness(snapshotDate: date, fetchedAt: ListHarness.now)])
        let viewModel = settingsViewModel(FakeSettings(), cache: cache)
        await viewModel.loadDataSource()
        #expect(viewModel.dataSource?.snapshotDate == date)
    }

    func onboarding(_ store: FakeSettings, location: FakeLocation) -> OnboardingViewModel {
        OnboardingViewModel(completeOnboarding: CompleteOnboarding(settings: store),
                            resolveProvinces: ResolveProvinces(provinces: FakeProvinces()),
                            locateUser: LocateUser(location: location, firstFixTimeout: .milliseconds(100)))
    }

    @Test func onboardingWithLocationSavesFuelAndTank() async {
        let store = FakeSettings()
        let viewModel = onboarding(store, location: FakeLocation())
        viewModel.next()
        #expect(viewModel.step == .fuel)
        viewModel.product = .petrol95E5
        viewModel.stepTankSize(by: -5)
        viewModel.next()
        #expect(viewModel.step == .location)

        await viewModel.useLocation()
        #expect(viewModel.isFinished)
        let saved = await store.settings
        #expect(saved.onboardingCompleted)
        #expect(saved.product == .petrol95E5)
        #expect(saved.tankSize == 50)
        #expect(saved.defaultProvinceID == nil)
    }

    @Test func deniedLocationAsksForAProvince() async {
        let store = FakeSettings()
        let viewModel = onboarding(store, location: FakeLocation(authorization: .denied))
        viewModel.next()
        viewModel.next()
        await viewModel.useLocation()
        #expect(viewModel.step == .province)
        #expect(!viewModel.isFinished)
        #expect(viewModel.provinces.map(\.name) == ["Madrid"])

        await viewModel.choose(ProvinceID("28"))
        #expect(viewModel.isFinished)
        #expect(await store.settings.defaultProvinceID == ProvinceID("28"))
    }

    @Test func backGoesOneStepAtATime() {
        let viewModel = onboarding(FakeSettings(), location: FakeLocation())
        viewModel.next()
        viewModel.next()
        viewModel.back()
        #expect(viewModel.step == .fuel)
        viewModel.back()
        viewModel.back()
        #expect(viewModel.step == .welcome)
    }

    /// Found on the simulator: after "Elegir provincia" the list asked for location at once.
    @Test func openingTheListDoesNotAskForLocation() async {
        let location = PromptCountingLocation()
        let viewModel = StationListViewModel(
            observeNearby: ObserveNearbyStations(cache: FakeCache(), favorites: FakeFavorites()),
            refreshPrices: RefreshPrices(remote: FakeRemote(), cache: FakeCache()),
            resolveProvinces: ResolveProvinces(provinces: FakeProvinces()),
            observeConnectivity: ObserveConnectivity(connectivity: FakeConnectivity()),
            observeSettings: ObserveSettings(settings: FakeSettings()), updateSettings: UpdateSettings(settings: FakeSettings()),
            locateUser: LocateUser(location: location, firstFixTimeout: .milliseconds(50)),
            toggleFavorite: ToggleFavorite(favorites: FakeFavorites())
        )
        let task = Task { await viewModel.start() }
        await waitUntil { viewModel.state != .firstLoad }
        try? await Task.sleep(for: .milliseconds(100))
        #expect(await location.prompts == 0)
        task.cancel()
    }
}

/// Never answered permission, counting how often the app asks.
actor PromptCountingLocation: UserLocationRepository {
    private(set) var prompts = 0
    func authorization() async -> LocationAuthorization { .notDetermined }
    func requestAuthorization() async -> LocationAuthorization {
        prompts += 1
        return .notDetermined
    }
    func updates() async -> AsyncStream<Coordinate> { AsyncStream { _ in } }
}
