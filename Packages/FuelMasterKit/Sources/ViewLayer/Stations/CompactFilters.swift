import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// At accessibility text sizes the sort and the filter fold into one button (canvas: "Texto muy grande").
struct CompactFilters: View {
    @Bindable var viewModel: StationListViewModel

    var body: some View {
        Menu {
            Picker(selection: $viewModel.sort) {
                Text("Más barata", bundle: .module).tag(StationSort.cheapest)
                Text("Más cerca", bundle: .module).tag(StationSort.nearest)
            } label: {
                Text("Ordenar", bundle: .module)
            }
            Picker(selection: $viewModel.levelFilter) {
                ForEach(LevelFilter.allCases, id: \.self) { $0.title.tag($0) }
            } label: {
                Text("Filtro de precio", bundle: .module)
            }
        } label: {
            FilterIcon(isActive: viewModel.levelFilter != .all)
        }
        .plainAccentMenu()
        .accessibilityLabel(Text("Filtros", bundle: .module))
        .accessibilityValue(viewModel.levelFilter.title)
    }
}
