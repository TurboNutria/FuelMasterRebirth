import Foundation

/// Which provinces to load for a map viewport or a point, including neighbours near borders.
public struct ResolveProvinces: Sendable {
    /// About 10 km around a point, so stations just across a border are included.
    public static let borderMargin = 0.1

    private let provinces: any ProvinceRepository

    public init(provinces: any ProvinceRepository) {
        self.provinces = provinces
    }

    public func callAsFunction(viewport: MapViewport) async -> [ProvinceID] {
        await provinces.provinces(intersecting: viewport.bounds).sorted()
    }

    /// Every province, sorted by name, for "Provincia sin ubicación".
    public func all() async -> [Province] {
        await provinces.allProvinces().sorted {
            $0.name.compare($1.name, locale: Locale(identifier: "es_ES")) == .orderedAscending
        }
    }

    /// Name and bounds of one province, e.g. the default one when location is denied.
    public func province(_ id: ProvinceID) async -> Province? {
        await provinces.allProvinces().first { $0.id == id }
    }

    public func callAsFunction(around coordinate: Coordinate) async -> [ProvinceID] {
        let box = BoundingBox(minLatitude: coordinate.latitude, minLongitude: coordinate.longitude,
                              maxLatitude: coordinate.latitude, maxLongitude: coordinate.longitude)
            .expanded(by: Self.borderMargin)
        var result = Set(await provinces.provinces(intersecting: box))
        if let home = await provinces.province(at: coordinate) { result.insert(home) }
        return result.sorted()
    }
}
