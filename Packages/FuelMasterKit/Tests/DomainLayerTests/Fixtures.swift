import DomainLayer
import Foundation

enum Fixtures {
    static let madrid = TimeZone(identifier: "Europe/Madrid")!

    /// A date in Madrid local time.
    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = madrid
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    static func station(_ id: String, diesel: String?, at coordinate: Coordinate = Coordinate(latitude: 40.4169, longitude: -3.7035),
                        hours: OpeningHours = OpeningHours(rawText: "L-D: 24H", schedule: .alwaysOpen),
                        province: String = "28") -> Station {
        var prices: [Product: Price] = [:]
        if let diesel { prices[.diesel] = Price(amount: Decimal(string: diesel)!, product: .diesel) }
        return Station(
            id: StationID(id), name: "Station \(id)",
            address: Address(street: "C/ Test, \(id)", postcode: "28001", locality: "Madrid", municipality: "Madrid", province: "Madrid"),
            coordinate: coordinate, roadSide: .notApplicable, hours: hours,
            provinceID: ProvinceID(province), municipalityID: MunicipalityID("4354"), prices: prices
        )
    }
}

// MARK: - Fakes

actor FakeRemote: StationRemoteRepository {
    var snapshots: [ProvinceID: ProvinceSnapshot] = [:]
    var errors: [ProvinceID: DomainError] = [:]
    private(set) var requestedProvinces: [ProvinceID] = []
    private(set) var requestedDays: [Date] = []

    init(snapshots: [ProvinceID: ProvinceSnapshot] = [:], errors: [ProvinceID: DomainError] = [:]) {
        self.snapshots = snapshots
        self.errors = errors
    }

    func currentPrices(province: ProvinceID) async throws -> ProvinceSnapshot {
        requestedProvinces.append(province)
        if let error = errors[province] { throw error }
        guard let snapshot = snapshots[province] else { throw DomainError.notFound }
        return snapshot
    }

    func history(province: ProvinceID, product: Product, day: Date) async throws -> HistorySnapshot {
        requestedDays.append(day)
        return HistorySnapshot(provinceID: province, product: product, day: day, prices: [StationID("1"): 1])
    }
}

actor FakeCache: StationCacheRepository {
    var stored: [ProvinceID: [Station]] = [:]
    var freshnessByProvince: [ProvinceID: Freshness] = [:]
    var knownDays: Set<Date> = []
    var stationHistory: [HistoryPoint] = []
    var areaPoints: [HistoryPoint] = []
    private(set) var savedHistory: [Date] = []

    init(stored: [ProvinceID: [Station]] = [:], freshness: [ProvinceID: Freshness] = [:], knownDays: Set<Date> = []) {
        self.stored = stored
        self.freshnessByProvince = freshness
        self.knownDays = knownDays
    }

    func stations(in provinces: [ProvinceID]) async throws -> [Station] { provinces.flatMap { stored[$0] ?? [] } }
    func station(id: StationID) async throws -> Station? { stored.values.flatMap { $0 }.first { $0.id == id } }
    func save(_ snapshot: ProvinceSnapshot, fetchedAt: Date) async throws {
        stored[snapshot.provinceID] = snapshot.stations
        freshnessByProvince[snapshot.provinceID] = Freshness(snapshotDate: snapshot.snapshotDate, fetchedAt: fetchedAt)
    }
    func freshness(of province: ProvinceID) async throws -> Freshness? { freshnessByProvince[province] }
    func setHistory(_ points: [HistoryPoint], area: [HistoryPoint]) {
        stationHistory = points
        areaPoints = area
    }
    func history(station: StationID, product: Product, since day: Date) async throws -> [HistoryPoint] {
        stationHistory.filter { $0.day >= day }
    }
    func areaHistory(provinces: [ProvinceID], product: Product, since day: Date) async throws -> [HistoryPoint] {
        areaPoints.filter { $0.day >= day }
    }
    func historyDays(province: ProvinceID, product: Product, since day: Date) async throws -> Set<Date> { knownDays }
    func save(_ history: HistorySnapshot) async throws {
        savedHistory.append(history.day)
        knownDays.insert(history.day)
    }
    func deleteHistory(before day: Date) async throws {}
    func changes() async -> AsyncStream<Void> { AsyncStream { $0.finish() } }
}

actor FakeFavorites: FavoriteStationsRepository {
    var entries: [FavoriteEntry]
    init(_ ids: [String] = []) {
        entries = ids.enumerated().map { FavoriteEntry(stationID: StationID($1), provinceID: ProvinceID("28"), order: $0) }
    }
    func favorites() async throws -> [FavoriteEntry] { entries }
    func add(_ station: StationID, province: ProvinceID) async throws {
        entries.append(FavoriteEntry(stationID: station, provinceID: province, order: entries.count))
    }
    func remove(_ station: StationID) async throws { entries.removeAll { $0.stationID == station } }
    func move(from source: Int, to destination: Int) async throws {}
    func changes() async -> AsyncStream<[FavoriteEntry]> { AsyncStream { $0.finish() } }
    func iCloudStatus() async -> AsyncStream<ICloudStatus> { AsyncStream { $0.finish() } }
}

final class FakeWidgets: WidgetRefreshing, @unchecked Sendable {
    private(set) var reloads = 0
    func reloadAll() { reloads += 1 }
}

struct FakeProvinces: ProvinceRepository {
    var municipalities: [Municipality] = []
    func allProvinces() async -> [Province] { [] }
    func province(at coordinate: Coordinate) async -> ProvinceID? { ProvinceID("28") }
    func provinces(intersecting bounds: BoundingBox) async -> [ProvinceID] { [ProvinceID("28")] }
    func municipalities(matching text: String) async -> [Municipality] {
        municipalities.filter { SearchStations.fold($0.name).contains(SearchStations.fold(text)) }
    }
}

extension Fixtures {
    /// A station with a name, town and postcode of its own, for search and favourites.
    static func named(_ id: String, _ name: String, diesel: String, locality: String = "Madrid", postcode: String = "28005",
                      province: String = "28", metersNorth: Double = 0) -> Station {
        let base = station(id, diesel: diesel, province: province)
        return Station(
            id: base.id, name: name,
            address: Address(street: "C/ Test, \(id)", postcode: postcode, locality: locality, municipality: locality,
                             province: "Madrid"),
            coordinate: Coordinate(latitude: 40.4169 + metersNorth / 111_000, longitude: -3.7035),
            roadSide: .notApplicable, hours: base.hours, provinceID: base.provinceID,
            municipalityID: base.municipalityID, prices: base.prices
        )
    }
}
