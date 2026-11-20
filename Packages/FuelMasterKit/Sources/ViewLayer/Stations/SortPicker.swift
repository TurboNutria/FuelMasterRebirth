import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// "Más barata | Más cerca".
struct SortPicker: View {
    @Binding var sort: StationSort

    var body: some View {
        Picker(selection: $sort) {
            Text("Más barata", bundle: .module).tag(StationSort.cheapest)
            Text("Más cerca", bundle: .module).tag(StationSort.nearest)
        } label: {
            Text("Ordenar", bundle: .module)
        }
        .pickerStyle(.segmented)
    }
}
