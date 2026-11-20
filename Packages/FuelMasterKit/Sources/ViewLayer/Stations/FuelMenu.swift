import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// "Diésel ⌄": the fuel picker as a glass capsule menu.
struct FuelMenu: View {
    let product: Product
    let products: [Product]
    let onSelect: (Product) -> Void

    var body: some View {
        Menu {
            FuelPicker(product: product, products: products, onSelect: onSelect)
        } label: {
            Label { Text(product.displayName).lineLimit(1) } icon: { Image(systemName: "chevron.down") }
                .labelStyle(.trailingIcon)
        }
        .plainAccentMenu()
        .accessibilityLabel(Text("Combustible", bundle: .module))
        .accessibilityValue(Text(product.displayName))
    }
}
