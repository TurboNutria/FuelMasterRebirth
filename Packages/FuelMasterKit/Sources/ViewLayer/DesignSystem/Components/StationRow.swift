import DomainLayer
import SwiftUI
import ViewModelLayer

/// Brand tile with two letters instead of a logo ("BA", "RE").
public struct BrandBadge: View {
    let initials: String

    public init(_ initials: String) {
        self.initials = initials
    }

    public var body: some View {
        Text(initials)
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(ColorTokens.textSecondary)
            .frame(width: 40, height: 40)
            .background(ColorTokens.cell, in: .rect(cornerRadius: 10))
            .accessibilityHidden(true)
    }
}

/// One station in Gasolineras, Favoritos and Buscar: badge, name (+ star), hours · distance ·
/// street, and the price chip. VoiceOver reads it as one sentence (canvas: Accesibilidad).
/// At accessibility text sizes the row stacks into one column.
public struct StationRow: View {
    let summary: StationSummary
    let hours: HoursSummary

    @Environment(\.displayFormat) private var format
    @Environment(\.accentColors) private var accent
    @Environment(\.dynamicTypeSize) private var typeSize

    public init(_ summary: StationSummary, hours: HoursSummary) {
        self.summary = summary
        self.hours = hours
    }

    public var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    PriceChip(amount: summary.price.amount, level: summary.level)
                    title
                    HoursLabel(hours)
                    if let distance { Text(distance) }
                    Text(summary.station.address.street)
                }
                .font(.rowDetail)
                .foregroundStyle(ColorTokens.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 12) {
                    BrandBadge(summary.station.initials)
                    VStack(alignment: .leading, spacing: 2) {
                        title
                        detailLine
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    PriceChip(amount: summary.price.amount, level: summary.level)
                }
            }
        }
        .padding(.vertical, 10)
        .frame(minHeight: 60)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenText)
        .accessibilityAddTraits(.isButton)
    }

    private var title: some View {
        HStack(spacing: 5) {
            Text(summary.station.name)
                .font(.rowTitle)
                .foregroundStyle(ColorTokens.textPrimary)
                .lineLimit(2)
            if summary.isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(accent.fill)
            }
        }
    }

    private var detailLine: some View {
        // Hours and distance keep their width; the street is what truncates in narrow columns.
        HStack(spacing: 0) {
            HoursLabel(hours)
                .layoutPriority(2)
            Group {
                if let distance { Text(verbatim: " · \(distance)").layoutPriority(1) }
                Text(verbatim: " · \(summary.station.address.street)")
            }
            .foregroundStyle(ColorTokens.textSecondary)
        }
        .font(.rowDetail)
        .lineLimit(1)
    }

    private var distance: String? {
        summary.distance.map { format.distance(meters: $0) }
    }

    /// «Ballenoil. Diésel, 1,859 euros, barata. Abierta 24 horas. A 1,4 kilómetros.»
    private var spokenText: String {
        let product = String(localized: summary.price.product.displayName)
        let price = format.priceWithCurrency(summary.price.amount)
        var parts = [
            summary.station.name,
            String(localized: "\(product), \(price), \(summary.level.spokenName)", bundle: .module,
                   comment: "Row: product, price, level"),
            HoursLabel(hours).spokenText,
        ]
        if let distance { parts.append(String(localized: "A \(distance)", bundle: .module, comment: "Distance from you")) }
        if summary.isFavorite { parts.append(String(localized: "Favorita", bundle: .module)) }
        return parts.joined(separator: ". ")
    }
}
