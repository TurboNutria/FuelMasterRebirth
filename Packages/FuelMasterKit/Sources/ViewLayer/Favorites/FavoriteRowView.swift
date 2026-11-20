import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// A favourite: the usual station row with the change since yesterday, or a placeholder while its
/// province loads or when it doesn't sell the chosen fuel.
struct FavoriteRowView: View {
    let row: FavoriteRow
    let product: Product
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            if let summary = row.summary, let hours = row.hours {
                StationRow(summary, hours: hours, change: row.change, showsFavoriteStar: false)
            } else {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.item.station?.name ?? String(localized: "Gasolinera", bundle: .module))
                            .font(.rowTitle)
                            .foregroundStyle(ColorTokens.textPrimary)
                        Group {
                            if row.isNotSold {
                                Text("No vende \(String(localized: product.displayName))", bundle: .module)
                            } else {
                                Text("Cargando precios…", bundle: .module)
                            }
                        }
                        .font(.rowDetail)
                        .foregroundStyle(ColorTokens.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    PriceChip(amount: nil, level: nil)
                }
                .padding(.vertical, 12)
                .frame(minHeight: 60)
                .contentShape(.rect)
            }
        }
        .buttonStyle(.plain)
        .disabled(row.item.station == nil)
    }
}
