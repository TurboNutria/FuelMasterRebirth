import Foundation

/// Saves the onboarding answers and marks it done (Bear note 07, CompleteOnboarding).
public struct CompleteOnboarding: Sendable {
    private let settings: any SettingsRepository

    public init(settings: any SettingsRepository) {
        self.settings = settings
    }

    /// `defaultProvince` is set when the user picked one instead of sharing their location.
    public func callAsFunction(product: Product, tankSize: Decimal, defaultProvince: ProvinceID?) async {
        let tankSize = Settings.clampedTankSize(tankSize)
        await settings.update { current in
            current.product = product
            current.tankSize = tankSize
            if let defaultProvince { current.defaultProvinceID = defaultProvince }
            current.onboardingCompleted = true
        }
    }
}

public struct DataSourceInfo: Sendable, Equatable {
    /// The ministry's timestamp of the newest cached province, for "Datos del 20/10/2026, 17:28".
    public let snapshotDate: Date?

    public init(snapshotDate: Date?) {
        self.snapshotDate = snapshotDate
    }
}

/// What Fuente y aviso legal shows about the data (Bear note 07, GetDataSourceInfo).
public struct GetDataSourceInfo: Sendable {
    private let cache: any StationCacheRepository
    private let provinces: any ProvinceRepository

    public init(cache: any StationCacheRepository, provinces: any ProvinceRepository) {
        self.cache = cache
        self.provinces = provinces
    }

    public func callAsFunction() async -> DataSourceInfo {
        var newest: Date?
        for province in await provinces.allProvinces() {
            guard let date = try? await cache.freshness(of: province.id)?.snapshotDate else { continue }
            if newest == nil || date > newest! { newest = date }
        }
        return DataSourceInfo(snapshotDate: newest)
    }
}
