import DomainLayer
import Foundation
import NetworkLayer

/// Prices from the ministry's public REST service (v1 data source).
public struct MinistryRepository: StationRemoteRepository {
    private let network: any NetworkServiceProtocol
    private let urls: NetworkRepository

    public init(network: any NetworkServiceProtocol, urls: NetworkRepository = NetworkRepository()) {
        self.network = network
        self.urls = urls
    }

    public func currentPrices(province: ProvinceID) async throws -> ProvinceSnapshot {
        let list = try await fetch(urls.currentPrices(province: province))
        guard let date = MinistryDates.parse(list.date) else { throw DomainError.unreadableResponse }
        let stations = list.stations.compactMap { StationMapper.station(from: $0) }
        return ProvinceSnapshot(provinceID: province, stations: stations, snapshotDate: date)
    }

    public func history(province: ProvinceID, product: Product, day: Date) async throws -> HistorySnapshot {
        let list = try await fetch(urls.history(province: province, product: product, day: day))
        var prices: [StationID: Decimal] = [:]
        for dto in list.stations {
            guard dto.saleType.uppercased() != "R", let amount = MinistryNumbers.decimal(dto.productPrice) else { continue }
            prices[StationID(dto.id)] = amount
        }
        return HistorySnapshot(provinceID: province, product: product, day: day, prices: prices)
    }

    private func fetch(_ request: NetworkRequest) async throws -> StationListDTO {
        let list: StationListDTO
        do {
            list = try await network.decode(StationListDTO.self, from: request)
        } catch {
            throw Self.map(error)
        }
        guard list.result.uppercased() == "OK" else { throw DomainError.serverUnavailable }
        return list
    }

    static func map(_ error: NetworkError) -> DomainError {
        switch error {
        case .offline: .offline
        case .timedOut, .http, .invalidResponse: .serverUnavailable
        case .decoding: .unreadableResponse
        }
    }
}
