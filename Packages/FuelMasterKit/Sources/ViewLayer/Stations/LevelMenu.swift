import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// The level filter as one glass menu, for when the chips don't fit.
struct LevelMenu: View {
    @Binding var selection: LevelFilter

    var body: some View {
        Menu {
            Picker(selection: $selection) {
                ForEach(LevelFilter.allCases, id: \.self) { $0.title.tag($0) }
            } label: {
                Text("Filtro de precio", bundle: .module)
            }
        } label: {
            FilterIcon(isActive: selection != .all)
        }
        .plainAccentMenu()
        .accessibilityLabel(Text("Filtro de precio", bundle: .module))
        .accessibilityValue(selection.title)
    }
}
