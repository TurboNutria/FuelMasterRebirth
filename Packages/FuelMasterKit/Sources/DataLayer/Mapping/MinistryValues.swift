import DomainLayer
import Foundation

/// The ministry's number format: decimal comma, empty meaning "not sold".
enum MinistryNumbers {
    static func decimal(_ text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return Decimal(string: trimmed.replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX"))
    }

    static func double(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }
}

/// The ministry's timestamps (`Fecha`): `dd/MM/yyyy H:mm:ss`, Madrid local time.
public enum MinistryDates {
    public static let timeZone = TimeZone(identifier: "Europe/Madrid")!

    static func parse(_ text: String) -> Date? {
        let parts = text.split(whereSeparator: { $0 == " " || $0 == "/" || $0 == ":" }).compactMap { Int($0) }
        guard parts.count >= 3 else { return nil }
        var components = DateComponents()
        components.timeZone = timeZone
        components.day = parts[0]
        components.month = parts[1]
        components.year = parts[2]
        components.hour = parts.count > 3 ? parts[3] : 0
        components.minute = parts.count > 4 ? parts[4] : 0
        components.second = parts.count > 5 ? parts[5] : 0
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: components)
    }
}

/// Key of each product's price in the all-products responses.
enum ProductFields {
    static func priceKey(for product: Product) -> String {
        switch product {
        case .diesel: "Precio Gasoleo A"
        case .dieselPremium: "Precio Gasoleo Premium"
        case .petrol95E5: "Precio Gasolina 95 E5"
        case .petrol95Premium: "Precio Gasolina 95 E5 Premium"
        case .petrol98E5: "Precio Gasolina 98 E5"
        case .lpg: "Precio Gases licuados del petróleo"
        case .cng: "Precio Gas Natural Comprimido"
        case .lng: "Precio Gas Natural Licuado"
        case .renewableDiesel: "Precio Diésel Renovable"
        case .adBlue: "Precio Adblue"
        }
    }

    /// Read when the main key is empty: the E10 blend of the same petrol.
    static func fallbackPriceKey(for product: Product) -> String? {
        switch product {
        case .petrol95E5: "Precio Gasolina 95 E10"
        case .petrol98E5: "Precio Gasolina 98 E10"
        default: nil
        }
    }
}
