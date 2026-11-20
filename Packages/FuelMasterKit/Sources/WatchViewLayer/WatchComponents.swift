#if os(watchOS)
import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// The coloured price capsule in watch rows ("1,859"), in the user's price scale.
struct WatchPriceChip: View {
    let amount: Decimal?
    let level: PriceLevel?

    @Environment(\.priceScale) private var scale
    @Environment(\.displayFormat) private var format

    var body: some View {
        let colors = level.map { PriceLevelColors.colors(for: $0, scale: scale) }
        Text(amount.map(format.price) ?? "---")
            .font(.watchChip)
            .monospacedDigit()
            .foregroundStyle(colors?.foreground ?? ColorTokens.textSecondary)
            .padding(.vertical, 2)
            .padding(.horizontal, 8)
            .background(colors?.background ?? ColorTokens.cell, in: .capsule)
            .fixedSize()
    }
}

/// One station in Cerca and Favoritas: logo and name, then the price chip and a short note
/// (the distance, or the change since yesterday), and "Cerrada" only when it's closed.
struct WatchStationRow: View {
    let summary: StationSummary?
    let name: String
    let brand: Brand?
    let hours: HoursSummary?
    /// Favoritas shows the change since yesterday (only when it moved) instead of the distance.
    var showsChange = false
    var change: PriceChange?

    @Environment(\.displayFormat) private var format

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            StationLogo(brand: brand, size: 22)
            VStack(alignment: .leading, spacing: 6) {
                Text(name)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    WatchPriceChip(amount: summary?.price.amount, level: summary?.level)
                    if showsChange {
                        if let change, change.direction != .same { WatchChangeText(change: change) }
                    } else if let distance = summary?.distance {
                        Text(format.distance(meters: distance))
                            .font(.footnote)
                            .monospacedDigit()
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }
                if let hours, hours.isClosed {
                    Text("Cerrada", bundle: .module)
                        .font(.footnote)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: spokenText))
    }

    /// «Ballenoil. 1,859 €, barata. Abierta 24 horas. A 1,4 km.»
    private var spokenText: String {
        var parts = [name]
        if let summary {
            parts.append("\(format.priceWithCurrency(summary.price.amount)), \(summary.level.spokenName)")
        }
        if let hours { parts.append(hours.spokenText) }
        if !showsChange, let distance = summary?.distance {
            parts.append(String(localized: "A \(format.distance(meters: distance))", bundle: .module,
                                comment: "Distance from you"))
        }
        if showsChange, let change { parts.append(WatchChangeText(change: change).spokenText) }
        return parts.joined(separator: ". ")
    }
}

/// "↓ 0,005" in green, "↑ 0,010" in red: today against yesterday.
struct WatchChangeText: View {
    let change: PriceChange

    @Environment(\.displayFormat) private var format

    var body: some View {
        Text(verbatim: "\(change.difference < 0 ? "↓" : "↑") \(format.price(abs(change.difference)))")
            .font(.footnote.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(change.difference < 0 ? ColorTokens.priceDown : ColorTokens.priceUp)
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

/// "Diésel ⌄" under the title: the fuel, and the way to change it. Plain tinted text on the
/// page, not a glass capsule (Bear note 05, round 12).
struct FuelButton: View {
    let product: Product
    let action: () -> Void

    @Environment(\.accentColors) private var accent

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "fuelpump.fill")
                    .foregroundStyle(accent.tint)
                Text(product.watchName)
                    .font(.headline)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Combustible: \(product.watchName)", bundle: .module))
    }
}

/// "Hace 3 h" in red: the prices haven't been updated for over an hour (as on the widgets).
struct StalePill: View {
    let age: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "wifi.slash").imageScale(.small)
            Text(age)
        }
        .font(.footnote.weight(.bold))
        .foregroundStyle(.white)
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .background(ColorTokens.offline, in: .capsule)
        .accessibilityElement(children: .combine)
    }
}

/// A short centred message: first load, nothing nearby, no favourites, no connection.
struct WatchMessage: View {
    let systemImage: String?
    let text: String

    var body: some View {
        VStack(spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            Text(text)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
#endif
