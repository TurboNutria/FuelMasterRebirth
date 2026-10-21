@testable import DataLayer
import DomainLayer
import Foundation
@testable import NetworkLayer
import Testing

enum FixtureLoader {
    static func data(_ name: String) throws -> Foundation.Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return NetworkService.removingByteOrderMark(try Foundation.Data(contentsOf: url))
    }

    static func stationList(_ name: String) throws -> StationListDTO {
        try JSONDecoder().decode(StationListDTO.self, from: data(name))
    }
}

/// Answers every request with one fixture file.
struct FixtureNetwork: NetworkServiceProtocol {
    let fixture: String

    func data(for request: NetworkRequest) async throws(NetworkError) -> Foundation.Data {
        do { return try FixtureLoader.data(fixture) } catch { throw .invalidResponse }
    }

    func decode<T: Decodable & Sendable>(_ type: T.Type, from request: NetworkRequest) async throws(NetworkError) -> T {
        let body = try await data(for: request)
        do { return try JSONDecoder().decode(T.self, from: body) } catch { throw .decoding("\(error)") }
    }
}

@Suite("MinistryRepository against real responses")
struct MinistryRepositoryTests {
    @Test func mapsAllProductsForAProvince() async throws {
        let repository = MinistryRepository(network: FixtureNetwork(fixture: "EstacionesTerrestres_FiltroProvincia_28"))
        let snapshot = try await repository.currentPrices(province: ProvinceID("28"))

        // 895 rows; one (Valdemoro) is published at 0,0 and dropped.
        #expect(snapshot.stations.count == 894)
        let ballenoil = try #require(snapshot.stations.first { $0.id == StationID("3213") })
        #expect(ballenoil.name == "Ballenoil")
        #expect(ballenoil.address.street == "Ronda Segovia, 37")
        #expect(ballenoil.price(for: .diesel)?.amount == Decimal(string: "1.859"))
        #expect(ballenoil.price(for: .dieselPremium)?.amount == Decimal(string: "1.879"))
        #expect(ballenoil.price(for: .petrol95E5)?.amount == Decimal(string: "1.729"))
        #expect(ballenoil.price(for: .lpg) == nil)
        #expect(ballenoil.hours.schedule == .alwaysOpen)
        #expect(ballenoil.provinceID == ProvinceID("28"))
    }

    @Test func mapsAHistoryDay() async throws {
        let repository = MinistryRepository(network: FixtureNetwork(fixture: "EstacionesTerrestresHist_FiltroProvinciaProducto_19-10-2026_28_4"))
        let day = Date(timeIntervalSince1970: 0)
        let snapshot = try await repository.history(province: ProvinceID("28"), product: .diesel, day: day)

        #expect(snapshot.prices.count > 800)
        #expect(snapshot.prices[StationID("3213")] == Decimal(string: "1.859"))
        #expect(snapshot.day == day)
    }

    @Test func badCoordinatesAreFixedOrDropped() throws {
        let zero = StationDTO(fields: ["IDEESS": "1", "Tipo Venta": "P", "Latitud": "0,000000", "Longitud (WGS84)": "0,000000"])
        #expect(StationMapper.station(from: zero) == nil)
        // Tui (Pontevedra) is published with latitude and longitude swapped.
        let swapped = StationDTO(fields: ["IDEESS": "2", "Tipo Venta": "P", "Latitud": "-8,659472", "Longitud (WGS84)": "42,037472"])
        let station = try #require(StationMapper.station(from: swapped))
        #expect(station.coordinate == Coordinate(latitude: 42.037472, longitude: -8.659472))
    }

    @Test func restrictedStationsNeverReachTheDomain() {
        let dto = StationDTO(fields: ["IDEESS": "1", "Tipo Venta": "R", "Latitud": "40,4", "Longitud (WGS84)": "-3,7"])
        #expect(StationMapper.station(from: dto) == nil)
    }
}

@Suite("Bundled geography")
struct GeographyTests {
    let geography = GeographyStore.bundled()

    @Test func loadsEveryProvince() {
        #expect(geography.provinces.count == 52)
        #expect(geography.municipalities.count > 3000)
    }

    @Test(arguments: [
        (40.4169, -3.7035, "28"),  // Madrid, Puerta del Sol
        (41.3870, 2.1700, "08"),   // Barcelona
        (39.8628, -4.0273, "45"),  // Toledo
        (37.3891, -5.9845, "41"),  // Sevilla
        (28.4636, -16.2518, "38"), // Santa Cruz de Tenerife
    ])
    func findsTheProvinceOfAPoint(latitude: Double, longitude: Double, expected: String) {
        #expect(geography.province(at: Coordinate(latitude: latitude, longitude: longitude)) == ProvinceID(expected))
    }

    @Test func viewportAcrossABorderLoadsBothProvinces() {
        // Around Aranjuez, on the Madrid–Toledo border.
        let box = BoundingBox(minLatitude: 39.95, minLongitude: -3.75, maxLatitude: 40.10, maxLongitude: -3.45)
        let ids = Set(geography.provinces(intersecting: box))
        #expect(ids.isSuperset(of: [ProvinceID("28"), ProvinceID("45")]))
    }

    @Test func centralMadridOnlyLoadsMadrid() {
        // Regression: stations published at 0,0 used to stretch Cantabria's outline over Madrid.
        let box = BoundingBox(minLatitude: 40.3169, minLongitude: -3.8035, maxLatitude: 40.5169, maxLongitude: -3.6035)
        #expect(geography.provinces(intersecting: box) == [ProvinceID("28")])
    }

    @Test func municipalitySearchIgnoresAccents() {
        #expect(geography.municipalities(matching: "avila").contains { $0.provinceID == ProvinceID("05") })
    }
}

@Suite("Local storage", .serialized)
struct LocalStorageTests {
    @Test func savesAndReadsBackAProvince() async throws {
        let repository = LocalDataRepository(container: try PersistenceFactory.cacheContainer(inMemory: true),
                                             defaults: UserDefaults(suiteName: "tests.\(UUID())")!)
        let snapshot = try await MinistryRepository(network: FixtureNetwork(fixture: "EstacionesTerrestres_FiltroProvincia_28"))
            .currentPrices(province: ProvinceID("28"))
        let fetchedAt = Date()
        try await repository.save(snapshot, fetchedAt: fetchedAt)

        let stations = try await repository.stations(in: [ProvinceID("28")])
        #expect(stations.count == 894)
        #expect(try await repository.station(id: StationID("3213"))?.price(for: .diesel)?.amount == Decimal(string: "1.859"))
        #expect(try await repository.freshness(of: ProvinceID("28"))?.fetchedAt == fetchedAt)

        // Saving again replaces rather than duplicates.
        try await repository.save(snapshot, fetchedAt: fetchedAt)
        #expect(try await repository.stations(in: [ProvinceID("28")]).count == 894)
    }

    @Test func storesHistoryAndAreaAverages() async throws {
        let repository = LocalDataRepository(container: try PersistenceFactory.cacheContainer(inMemory: true),
                                             defaults: UserDefaults(suiteName: "tests.\(UUID())")!)
        let day = Date(timeIntervalSince1970: 1_000_000)
        try await repository.save(HistorySnapshot(provinceID: ProvinceID("28"), product: .diesel, day: day,
                                                  prices: [StationID("1"): 2, StationID("2"): 1]))
        #expect(try await repository.history(station: StationID("1"), product: .diesel, since: day).first?.amount == 2)
        #expect(try await repository.areaHistory(provinces: [ProvinceID("28")], product: .diesel, since: day).first?.amount == Decimal(string: "1.5"))
        #expect(try await repository.historyDays(province: ProvinceID("28"), product: .diesel, since: day) == [day])
    }

    @Test func settingsRoundTrip() async {
        let repository = LocalDataRepository(container: try! PersistenceFactory.cacheContainer(inMemory: true),
                                             defaults: UserDefaults(suiteName: "tests.\(UUID())")!)
        #expect(await repository.current() == .default)
        var settings = DomainLayer.Settings.default
        settings.product = .lng
        settings.tankSize = 20
        await repository.update(settings)
        #expect(await repository.current().product == .lng)
    }

    @Test func favoritesAreUniqueAndOrdered() async throws {
        let repository = FavoritesRepository(container: try PersistenceFactory.favoritesContainer(inMemory: true))
        try await repository.add(StationID("1"), province: ProvinceID("28"))
        try await repository.add(StationID("2"), province: ProvinceID("28"))
        try await repository.add(StationID("1"), province: ProvinceID("28"))
        #expect(try await repository.favorites().map(\.stationID.rawValue) == ["1", "2"])

        try await repository.move(from: 1, to: 0)
        #expect(try await repository.favorites().map(\.stationID.rawValue) == ["2", "1"])

        try await repository.remove(StationID("2"))
        #expect(try await repository.favorites().map(\.stationID.rawValue) == ["1"])
    }
}
