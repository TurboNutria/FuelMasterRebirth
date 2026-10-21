import DomainLayer
import Foundation

/// DTO → Domain, applying the app's rules on the way in.
enum StationMapper {
    /// Returns nil for restricted stations (members or fleets only, never shown) and broken rows.
    /// - Parameter singleProduct: for single-product endpoints, which product `PrecioProducto` holds.
    static func station(from dto: StationDTO, singleProduct: Product? = nil) -> Station? {
        guard dto.saleType.uppercased() != "R", !dto.id.isEmpty,
              let latitude = MinistryNumbers.double(dto.latitude),
              let longitude = MinistryNumbers.double(dto.longitude),
              let coordinate = coordinate(latitude: latitude, longitude: longitude) else { return nil }

        var prices: [Product: Price] = [:]
        if let singleProduct {
            if let amount = MinistryNumbers.decimal(dto.productPrice) {
                prices[singleProduct] = Price(amount: amount, product: singleProduct)
            }
        } else {
            for product in Product.allCases {
                if let amount = MinistryNumbers.decimal(dto[ProductFields.priceKey(for: product)]) {
                    prices[product] = Price(amount: amount, product: product)
                }
            }
        }

        return Station(
            id: StationID(dto.id),
            name: TextNormalizer.name(dto.sign),
            address: Address(
                street: TextNormalizer.address(dto.street),
                postcode: dto.postcode,
                locality: TextNormalizer.name(dto.locality),
                municipality: TextNormalizer.name(dto.municipality),
                province: TextNormalizer.name(dto.province)
            ),
            coordinate: coordinate,
            roadSide: roadSide(dto.roadSide),
            hours: OpeningHoursParser.parse(dto.hours),
            provinceID: ProvinceID(dto.provinceID),
            municipalityID: MunicipalityID(dto.municipalityID),
            prices: prices
        )
    }

    /// The ministry has a few stations at 0,0 and some with latitude and longitude swapped.
    /// Swapped pairs are fixed; anything else outside Spain is dropped, since it can't be placed on the map.
    static func coordinate(latitude: Double, longitude: Double) -> Coordinate? {
        if isInSpain(latitude: latitude, longitude: longitude) { return Coordinate(latitude: latitude, longitude: longitude) }
        if isInSpain(latitude: longitude, longitude: latitude) { return Coordinate(latitude: longitude, longitude: latitude) }
        return nil
    }

    /// Mainland, Balearics, Canaries, Ceuta and Melilla.
    static func isInSpain(latitude: Double, longitude: Double) -> Bool {
        (27.0...44.5).contains(latitude) && (-18.5...5.0).contains(longitude)
    }

    static func roadSide(_ code: String) -> RoadSide {
        switch code.uppercased() {
        case "D": .right
        case "I": .left
        default: .notApplicable
        }
    }
}
