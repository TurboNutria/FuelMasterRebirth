import DomainLayer
import Foundation
import Observation

/// Ajustes, Apariencia and Fuente y aviso legal (Bear note 07, section 5). One instance lives at
/// the root, because the look settings (accent, price scale, appearance) and the onboarding flag
/// apply to the whole app.
@MainActor @Observable
public final class SettingsViewModel {
    public private(set) var settings: Settings = .default
    /// False until the stored settings are read, so onboarding doesn't flash for returning users.
    public private(set) var isLoaded = false
    public private(set) var provinces: [Province] = []
    public private(set) var dataSource: DataSourceInfo?
    /// Changes being saved. Stream values that arrive meanwhile would undo what was just tapped.
    private var pendingChanges = 0

    private let observeSettings: ObserveSettings
    private let updateSettings: UpdateSettings
    private let resolveProvinces: ResolveProvinces
    private let getDataSourceInfo: GetDataSourceInfo

    public init(observeSettings: ObserveSettings, updateSettings: UpdateSettings,
                resolveProvinces: ResolveProvinces, getDataSourceInfo: GetDataSourceInfo) {
        self.observeSettings = observeSettings
        self.updateSettings = updateSettings
        self.resolveProvinces = resolveProvinces
        self.getDataSourceInfo = getDataSourceInfo
    }

    public var defaultProvinceName: String? {
        settings.defaultProvinceID.flatMap { id in provinces.first { $0.id == id }?.name }
    }

    // MARK: Intents

    /// Runs for the app's lifetime (from the root view).
    public func start() async {
        settings = await observeSettings.current()
        isLoaded = true
        provinces = await resolveProvinces.all()
        // Each emission re-reads the store, so a late, older value can't undo a newer change.
        for await _ in await observeSettings() where pendingChanges == 0 {
            settings = await observeSettings.current()
        }
    }

    /// Fuente y aviso legal: the date of the newest prices.
    public func loadDataSource() async {
        dataSource = await getDataSourceInfo()
    }

    public func select(_ product: Product) async { await change { $0.product = product } }

    public func setTankSize(_ size: Decimal) async {
        await change { $0.tankSize = Settings.clampedTankSize(size) }
    }

    public func stepTankSize(by litres: Decimal) async {
        await setTankSize(settings.tankSize + litres)
    }

    public func setAccent(_ accent: AccentChoice) async { await change { $0.accent = accent } }
    public func setPriceScale(_ scale: PriceScale) async { await change { $0.priceScale = scale } }
    public func setAppearance(_ appearance: Appearance) async { await change { $0.appearance = appearance } }
    public func setDefaultProvince(_ id: ProvinceID?) async { await change { $0.defaultProvinceID = id } }

    /// Shown at once, then saved; the settings stream confirms it.
    private func change(_ edit: @escaping @Sendable (inout Settings) -> Void) async {
        pendingChanges += 1
        edit(&settings)
        await updateSettings(edit)
        pendingChanges -= 1
    }
}
