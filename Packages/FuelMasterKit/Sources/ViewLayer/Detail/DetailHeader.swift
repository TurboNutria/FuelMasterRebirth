import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

struct DetailHeader: View {
    let content: StationDetailContent

    @Environment(\.displayFormat) private var format

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                if let brand = content.station.brand {
                    BrandLogo(brand: brand, size: 40)
                }
                Text(content.station.name)
                    .font(.system(.title, design: .rounded, weight: .heavy))
                    .foregroundStyle(ColorTokens.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(.bottom, 4)
            Text(addressLine)
                .foregroundStyle(ColorTokens.textSecondary)
            HStack(spacing: 0) {
                HoursLabel(content.hours)
                if let distance = distanceText {
                    // One run of text with the dot, as in the rows: a lone "·" fails the contrast check.
                    Text(verbatim: " · \(distance)")
                        .monospacedDigit()
                }
            }
            .foregroundStyle(ColorTokens.textSecondary)
            // One sentence for VoiceOver, without the "·" read as its own item.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: hoursAndDistanceSpoken))
            .accessibilityAddTraits(.isStaticText)
        }
        .font(.subheadline)
    }

    /// «a 1,4 km».
    private var distanceText: String? {
        content.detail.distance.map { distance in
            String(localized: "a \(format.distance(meters: distance))", bundle: .module,
                   comment: "Distance inside a sentence: a 1,4 km")
        }
    }

    /// «Abierta 24 horas, a 1,4 km».
    private var hoursAndDistanceSpoken: String {
        let hours = HoursLabel(content.hours).spokenText
        guard let distanceText else { return hours }
        return "\(hours), \(distanceText)"
    }

    private var addressLine: String {
        let address = content.station.address
        return "\(address.street) · \(address.postcode) \(address.locality)"
    }
}
