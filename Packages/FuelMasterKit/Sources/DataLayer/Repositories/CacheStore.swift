import DomainLayer
import Foundation
import SwiftData

/// SwiftData work for the local cache, off the main thread. `@Model` objects never leave this actor:
/// everything is converted to Domain values before returning.
@ModelActor
actor CacheStore {
    func stations(in provinces: [ProvinceID]) throws -> [Station] {
        let ids = provinces.map(\.rawValue)
        let descriptor = FetchDescriptor<CachedStation>(predicate: #Predicate { ids.contains($0.provinceID) })
        return try modelContext.fetch(descriptor).map(Self.station)
    }

    func station(id: StationID) throws -> Station? {
        let raw = id.rawValue
        var descriptor = FetchDescriptor<CachedStation>(predicate: #Predicate { $0.stationID == raw })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first.map(Self.station)
    }

    func save(_ snapshot: ProvinceSnapshot, fetchedAt: Date) throws {
        let province = snapshot.provinceID.rawValue
        let existing = try modelContext.fetch(FetchDescriptor<CachedStation>(predicate: #Predicate { $0.provinceID == province }))
        let incoming = Set(snapshot.stations.map(\.id.rawValue))
        // Stations that left the province's list are removed; the rest are replaced in place.
        for station in existing where !incoming.contains(station.stationID) { modelContext.delete(station) }
        let byID = Dictionary(existing.map { ($0.stationID, $0) }, uniquingKeysWith: { first, _ in first })

        for station in snapshot.stations {
            let record = byID[station.id.rawValue] ?? {
                let created = Self.record(for: station, at: fetchedAt)
                modelContext.insert(created)
                return created
            }()
            Self.update(record, with: station, at: fetchedAt)
            for price in record.prices { modelContext.delete(price) }
            record.prices = station.prices.values.map {
                CachedPrice(productID: $0.product.rawValue, amount: $0.amount, snapshotDate: snapshot.snapshotDate)
            }
        }

        let bookkeeping = try modelContext.fetch(FetchDescriptor<CachedProvinceSnapshot>(predicate: #Predicate { $0.provinceID == province })).first
        if let bookkeeping {
            bookkeeping.snapshotDate = snapshot.snapshotDate
            bookkeeping.fetchedAt = fetchedAt
            bookkeeping.stationCount = snapshot.stations.count
        } else {
            modelContext.insert(CachedProvinceSnapshot(provinceID: province, snapshotDate: snapshot.snapshotDate,
                                                       fetchedAt: fetchedAt, stationCount: snapshot.stations.count))
        }
        try modelContext.save()
    }

    func freshness(of province: ProvinceID) throws -> Freshness? {
        let raw = province.rawValue
        let record = try modelContext.fetch(FetchDescriptor<CachedProvinceSnapshot>(predicate: #Predicate { $0.provinceID == raw })).first
        return record.map { Freshness(snapshotDate: $0.snapshotDate, fetchedAt: $0.fetchedAt) }
    }

    func history(station: StationID, product: Product, since day: Date) throws -> [HistoryPoint] {
        let raw = station.rawValue, productID = product.rawValue
        let descriptor = FetchDescriptor<CachedHistoryPoint>(
            predicate: #Predicate { $0.stationID == raw && $0.productID == productID && $0.day >= day },
            sortBy: [SortDescriptor(\.day)]
        )
        return try modelContext.fetch(descriptor).map { HistoryPoint(day: $0.day, amount: $0.amount) }
    }

    func areaHistory(provinces: [ProvinceID], product: Product, since day: Date) throws -> [HistoryPoint] {
        let ids = provinces.map(\.rawValue), productID = product.rawValue
        let descriptor = FetchDescriptor<CachedAreaHistory>(
            predicate: #Predicate { ids.contains($0.provinceID) && $0.productID == productID && $0.day >= day },
            sortBy: [SortDescriptor(\.day)]
        )
        // Several provinces on the same day are averaged together.
        let grouped = Dictionary(grouping: try modelContext.fetch(descriptor), by: \.day)
        return grouped.keys.sorted().map { day in
            let values = grouped[day]!.map(\.average)
            return HistoryPoint(day: day, amount: values.reduce(0, +) / Decimal(values.count))
        }
    }

    func historyDays(province: ProvinceID, product: Product, since day: Date) throws -> Set<Date> {
        let raw = province.rawValue, productID = product.rawValue
        let descriptor = FetchDescriptor<CachedAreaHistory>(
            predicate: #Predicate { $0.provinceID == raw && $0.productID == productID && $0.day >= day }
        )
        return Set(try modelContext.fetch(descriptor).map(\.day))
    }

    func save(_ history: HistorySnapshot) throws {
        let province = history.provinceID.rawValue, productID = history.product.rawValue, day = history.day
        try modelContext.delete(model: CachedHistoryPoint.self, where: #Predicate {
            $0.provinceID == province && $0.productID == productID && $0.day == day
        })
        try modelContext.delete(model: CachedAreaHistory.self, where: #Predicate {
            $0.provinceID == province && $0.productID == productID && $0.day == day
        })
        for (station, amount) in history.prices {
            modelContext.insert(CachedHistoryPoint(stationID: station.rawValue, provinceID: province,
                                                   productID: productID, day: day, amount: amount))
        }
        if let average = history.average {
            modelContext.insert(CachedAreaHistory(provinceID: province, productID: productID, day: day, average: average))
        }
        try modelContext.save()
    }

    func deleteHistory(before day: Date) throws {
        try modelContext.delete(model: CachedHistoryPoint.self, where: #Predicate { $0.day < day })
        try modelContext.delete(model: CachedAreaHistory.self, where: #Predicate { $0.day < day })
        try modelContext.save()
    }

    // MARK: - Mapping

    private static func record(for station: Station, at date: Date) -> CachedStation {
        CachedStation(stationID: station.id.rawValue, name: station.name, street: station.address.street,
                      postcode: station.address.postcode, locality: station.address.locality,
                      municipality: station.address.municipality, municipalityID: station.municipalityID.rawValue,
                      provinceName: station.address.province, provinceID: station.provinceID.rawValue,
                      latitude: station.coordinate.latitude, longitude: station.coordinate.longitude,
                      roadSide: station.roadSide.rawValue, hoursText: station.hours.rawText, updatedAt: date)
    }

    private static func update(_ record: CachedStation, with station: Station, at date: Date) {
        record.name = station.name
        record.street = station.address.street
        record.postcode = station.address.postcode
        record.locality = station.address.locality
        record.municipality = station.address.municipality
        record.municipalityID = station.municipalityID.rawValue
        record.provinceName = station.address.province
        record.provinceID = station.provinceID.rawValue
        record.latitude = station.coordinate.latitude
        record.longitude = station.coordinate.longitude
        record.roadSide = station.roadSide.rawValue
        record.hoursText = station.hours.rawText
        record.updatedAt = date
    }

    private static func station(_ record: CachedStation) -> Station {
        var prices: [Product: Price] = [:]
        for cached in record.prices {
            // An E5 price wins over an E10 one cached before the two were merged.
            guard let product = Product(storedID: cached.productID),
                  prices[product] == nil || product.rawValue == cached.productID else { continue }
            prices[product] = Price(amount: cached.amount, product: product)
        }
        return Station(
            id: StationID(record.stationID),
            name: record.name,
            address: Address(street: record.street, postcode: record.postcode, locality: record.locality,
                             municipality: record.municipality, province: record.provinceName),
            coordinate: Coordinate(latitude: record.latitude, longitude: record.longitude),
            roadSide: RoadSide(rawValue: record.roadSide) ?? .notApplicable,
            hours: OpeningHoursParser.parse(record.hoursText),
            provinceID: ProvinceID(record.provinceID),
            municipalityID: MunicipalityID(record.municipalityID),
            prices: prices
        )
    }
}
