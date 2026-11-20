import Foundation

/// The area a screen, widget or background refresh works with.
public struct ResolvedArea: Sendable, Equatable {
    /// The provinces to load.
    public let provinces: [ProvinceID]
    /// The stations to show within them.
    public let area: NearbyArea
    /// The position distances are measured from. Nil when only a province is known.
    public let origin: Coordinate?
    /// The province's name ("En Madrid"), when the area is a whole province.
    public let provinceName: String?

    public init(provinces: [ProvinceID], area: NearbyArea, origin: Coordinate?, provinceName: String?) {
        self.provinces = provinces
        self.area = area
        self.origin = origin
        self.provinceName = provinceName
    }
}

/// Where to look for stations: around a position when there is one, else a whole province, the
/// default one, then the last viewed one, then Madrid. The one rule shared by Gasolineras, Mapa,
/// Buscar, the widgets and the background refresh.
public struct ResolveArea: Sendable {
    /// Gasolineras' radius, also the widgets' "cheapest nearby", so both show the same station.
    public static let radius: Double = 3000
    /// Used when there's no location and no province set yet.
    public static let fallbackProvince = ProvinceID("28")

    private let resolveProvinces: ResolveProvinces

    public init(provinces: any ProvinceRepository) {
        resolveProvinces = ResolveProvinces(provinces: provinces)
    }

    /// The province to show without a position.
    public static func province(for settings: Settings) -> ProvinceID {
        settings.defaultProvinceID ?? settings.lastViewedProvinceID ?? fallbackProvince
    }

    /// Within `radius` of a position, loading the provinces around it.
    public func callAsFunction(around location: Coordinate) async -> ResolvedArea {
        ResolvedArea(provinces: await resolveProvinces(around: location),
                     area: .radius(center: location, meters: Self.radius), origin: location, provinceName: nil)
    }

    /// A whole province. Nil when the province isn't in the bundled outlines.
    public func callAsFunction(province id: ProvinceID) async -> ResolvedArea? {
        guard let province = await resolveProvinces.province(id) else { return nil }
        return ResolvedArea(provinces: [id], area: .bounds(province.bounds), origin: nil, provinceName: province.name)
    }

    /// Without a live position (widgets, background refresh): where the app last saw the user,
    /// else the province from the settings.
    public func callAsFunction(_ settings: Settings) async -> ResolvedArea? {
        if let location = settings.lastLocation { return await self(around: location) }
        return await self(province: Self.province(for: settings))
    }
}
