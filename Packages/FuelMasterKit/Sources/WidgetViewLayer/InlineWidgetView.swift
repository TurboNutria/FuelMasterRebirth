import DesignTokens
#if os(iOS)
import DomainLayer
import SwiftUI
import ViewModelLayer
import WidgetKit

/// «⛽ 1,859 € · Ballenoil»
public struct InlineWidgetView: View {
    let content: WidgetContent

    @Environment(\.displayFormat) private var format

    public init(content: WidgetContent) {
        self.content = content
    }

    public var body: some View {
        Group {
            if let station = content.cheapest {
                Label {
                    Text(verbatim: "\(format.priceWithCurrency(station.price)) · \(station.name)")
                } icon: {
                    Image(systemName: "fuelpump")
                }
            } else {
                Label { Text("Sin precios", bundle: .module) } icon: { Image(systemName: "fuelpump") }
            }
        }
        .widgetURL(content.cheapest?.link)
        .containerBackground(for: .widget) { Color.clear }
    }
}
#endif
