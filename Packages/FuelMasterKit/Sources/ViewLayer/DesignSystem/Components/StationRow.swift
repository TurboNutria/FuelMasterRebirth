import DomainLayer
import SwiftUI
import ViewModelLayer

/// One station in Gasolineras, Favoritos and Buscar: logo, name (+ star), hours · distance ·
/// street, and the price chip. VoiceOver reads it as one sentence (canvas: Accesibilidad).
/// At accessibility text sizes the row stacks into one column.
public struct StationRow: View {
    let summary: StationSummary
    let hours: HoursSummary
    /// Favoritos: today against yesterday, under the chip ("↓ 0,020 €", "= igual").
    let change: PriceChange?
    /// Buscar: what to highlight, and where.
    let highlight: SearchHighlight?
    /// Off in Favoritos, where every row is one.
    let showsFavoriteStar: Bool

    @Environment(\.displayFormat) private var format
    @Environment(\.accentColors) private var accent
    @Environment(\.dynamicTypeSize) private var typeSize

    public init(_ summary: StationSummary, hours: HoursSummary, change: PriceChange? = nil,
                highlight: SearchHighlight? = nil, showsFavoriteStar: Bool = true) {
        self.summary = summary
        self.hours = hours
        self.change = change
        self.highlight = highlight
        self.showsFavoriteStar = showsFavoriteStar
    }

    public var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        PriceChip(amount: summary.price.amount, level: summary.level)
                        if let visibleChange { ChangeLabel(change: visibleChange) }
                    }
                    title
                    HoursLabel(hours)
                    if let distance { Text(distance) }
                    Text(place(separated: false)).foregroundStyle(ColorTokens.textSecondary)
                }
                .font(.rowDetail)
                .foregroundStyle(ColorTokens.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 16) {
                    StationLogo(brand: summary.station.brand, size: 36)
                        .padding(.trailing, -4)
                    VStack(alignment: .leading, spacing: 4) {
                        title
                        detailLine
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 4) {
                        PriceChip(amount: summary.price.amount, level: summary.level)
                        if let visibleChange { ChangeLabel(change: visibleChange) }
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .frame(minHeight: 60)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenText)
        .accessibilityAddTraits(.isButton)
    }

    private var title: some View {
        HStack(spacing: 4) {
            Text(highlighted(summary.station.name, when: .name))
                .font(.rowTitle)
                .foregroundStyle(ColorTokens.textPrimary)
                .lineLimit(2)
            if summary.isFavorite, showsFavoriteStar {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(accent.fill)
            }
        }
    }

    /// Always "hours · distance" first, then the street: on the same line when it fits, otherwise
    /// on its own line below, wrapping rather than being cut to a few letters.
    private var detailLine: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                hoursAndDistance
                Text(place(separated: true)).lineLimit(1)
            }
            VStack(alignment: .leading, spacing: 4) {
                hoursAndDistance
                Text(place(separated: false))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.rowDetail)
        .foregroundStyle(ColorTokens.textSecondary)
    }

    private var hoursAndDistance: some View {
        HStack(spacing: 0) {
            HoursLabel(hours)
            if let distance {
                Text(verbatim: " · \(distance)").monospacedDigit()
            }
        }
        .lineLimit(1)
        .fixedSize()
    }

    /// The street, or "28005 Madrid" with the match highlighted when a search matched the place.
    private func place(separated: Bool) -> AttributedString {
        let address = summary.station.address
        let separator = AttributedString(separated ? " · " : "")
        switch highlight?.match {
        case .locality, .postcode:
            return separator + highlighted("\(address.postcode) \(address.locality)", when: highlight!.match)
        case .name, nil:
            return separator + AttributedString(address.street)
        }
    }

    private func highlighted(_ text: String, when match: SearchMatch) -> AttributedString {
        var attributed = AttributedString(text)
        guard let highlight, highlight.match == match,
              let range = attributed.range(of: highlight.text, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return attributed
        }
        attributed[range].backgroundColor = accent.fill.opacity(0.25)
        attributed[range].foregroundColor = ColorTokens.textPrimary
        return attributed
    }

    /// Only a real change shows under the chip; "same as yesterday" stays out of sight.
    private var visibleChange: PriceChange? {
        guard let change, change.direction != .same else { return nil }
        return change
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
        if let change { parts.append(ChangeLabel(change: change).spokenText) }
        if summary.isFavorite, showsFavoriteStar { parts.append(String(localized: "Favorita", bundle: .module)) }
        return parts.joined(separator: ". ")
    }
}

/// What Buscar highlights in a row: the typed text, in the name or in the place.
public struct SearchHighlight: Sendable, Equatable {
    public let text: String
    public let match: SearchMatch

    public init(text: String, match: SearchMatch) {
        self.text = text
        self.match = match
    }
}

/// Today against yesterday, in the chip's own number format: an arrow and "0,020" in green when
/// it went down, red when it went up. Rows hide it when the price is the same.
struct ChangeLabel: View {
    let change: PriceChange

    @Environment(\.displayFormat) private var format

    var body: some View {
        HStack(spacing: 2) {
            if let arrow { Image(systemName: arrow).imageScale(.small) }
            Text(format.price(abs(change.difference))).monospacedDigit()
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(color)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenText)
    }

    private var arrow: String? {
        switch change.direction {
        case .down: "arrow.down"
        case .up: "arrow.up"
        case .same: "equal"
        }
    }

    private var color: Color {
        switch change.direction {
        case .down: ColorTokens.priceDown
        case .up: ColorTokens.priceUp
        case .same: ColorTokens.textSecondary
        }
    }

    var spokenText: String {
        let amount = format.priceWithCurrency(abs(change.difference))
        switch change.direction {
        case .down: return String(localized: "Ha bajado \(amount) desde ayer", bundle: .module)
        case .up: return String(localized: "Ha subido \(amount) desde ayer", bundle: .module)
        case .same: return String(localized: "Igual que ayer", bundle: .module)
        }
    }
}

extension View {
    /// The row's VoiceOver actions (canvas: Accesibilidad): favourite and directions.
    func stationRowActions(_ station: Station, isFavorite: Bool, onToggleFavorite: @escaping () -> Void) -> some View {
        self
            .accessibilityAction(named: isFavorite ? Text("Quitar de favoritos", bundle: .module)
                                                   : Text("Añadir a favoritos", bundle: .module),
                                 onToggleFavorite)
            .accessibilityAction(named: Text("Cómo llegar", bundle: .module)) { station.openDirections() }
    }
}

/// The hairline between rows in Gasolineras and Buscar: one device pixel.
struct RowSeparator: View {
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Rectangle()
            .fill(ColorTokens.separator)
            .frame(height: 1 / displayScale)
    }
}
