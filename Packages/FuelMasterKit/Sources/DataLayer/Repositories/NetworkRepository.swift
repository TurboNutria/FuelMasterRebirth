import DomainLayer
import Foundation
import NetworkLayer

/// Builds the ministry's URLs (see Bear note 03).
public struct NetworkRepository: Sendable {
    public static let ministryBase = URL(string: "https://sedeaplicaciones.minetur.gob.es/ServiciosRESTCarburantes/PreciosCarburantes/")!

    private let base: URL

    public init(base: URL = NetworkRepository.ministryBase) {
        self.base = base
    }

    /// Every station of a province, with all products (≈ 945 KB for Madrid).
    public func currentPrices(province: ProvinceID) -> NetworkRequest {
        request("EstacionesTerrestres/FiltroProvincia/\(province.rawValue)")
    }

    /// One day's prices for a province and product (≈ 335 KB for Madrid).
    public func history(province: ProvinceID, product: Product, day: Date) -> NetworkRequest {
        request("EstacionesTerrestresHist/FiltroProvinciaProducto/\(Self.dayFormat(day))/\(province.rawValue)/\(product.rawValue)")
    }

    public func provinces() -> NetworkRequest { request("Listados/Provincias/") }
    public func products() -> NetworkRequest { request("Listados/ProductosPetroliferos/") }

    private func request(_ path: String) -> NetworkRequest {
        NetworkRequest(url: base.appending(path: path))
    }

    /// `dd-MM-yyyy` in Madrid time.
    static func dayFormat(_ day: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = MinistryDates.timeZone
        let parts = calendar.dateComponents([.day, .month, .year], from: day)
        return String(format: "%02d-%02d-%04d", parts.day ?? 1, parts.month ?? 1, parts.year ?? 1970)
    }
}
