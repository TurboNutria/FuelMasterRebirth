import DomainLayer
import SwiftUI

/// The fuel picker: inside the Gasolineras and Mapa menus, and on its own in Ajustes. A picker,
/// so the system draws the tick in its own column and the names stay aligned.
struct FuelPicker: View {
    let product: Product
    var products: [Product] = Product.allCases
    let onSelect: (Product) -> Void

    var body: some View {
        // The view models change the fuel through an async intent, so the binding hands the
        // choice to `onSelect` rather than writing a property.
        Picker(selection: Binding(get: { product }, set: onSelect)) {
            ForEach(products) { Text($0.displayName).tag($0) }
        } label: {
            Text("Combustible", bundle: .module)
        }
    }
}
