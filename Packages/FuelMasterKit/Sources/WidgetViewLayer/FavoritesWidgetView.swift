import DesignTokens
#if os(iOS)
import DomainLayer
import SwiftUI
import ViewModelLayer
import WidgetKit

public struct FavoritesWidgetView: View {
    let content: WidgetContent

    @Environment(\.widgetRenderingMode) private var renderingMode

    public init(content: WidgetContent) {
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .foregroundStyle(AccentColors.colors(for: content.accent).tint)
                    .widgetAccentable()
                Text("Favoritos", bundle: .module)
                Text(verbatim: "·")
                Text(content.product.displayName).lineLimit(1)
                Spacer(minLength: 4)
                if let age = content.favoritesStaleAge { StaleTag(age: age) }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(ColorTokens.textSecondary)

            if content.favorites.isEmpty {
                Text("Aún no tienes favoritas", bundle: .module)
                    .font(.subheadline)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 8) {
                    ForEach(content.favorites.prefix(3)) { station in
                        Link(destination: station.link) {
                            FavoriteWidgetRow(station: station, isStale: content.favoritesStaleAge != nil,
                                              accented: renderingMode != .fullColor)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { ColorTokens.surface }
        .environment(\.priceScale, content.priceScale)
    }
}
#endif
