import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// Favoritos (canvas: "Favoritos", "Favoritos vacío", iPad "Favoritos"): the cheapest favourite,
/// then the user's stations in their order with the change since yesterday. Swipe to remove;
/// Editar to reorder. Kept short on purpose: no explanatory text.
public struct FavoritesScreen: View {
    let viewModel: FavoritesViewModel

    @Environment(AppRouter.self) private var router
    @State private var isEditing = false

    public init(viewModel: FavoritesViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    FavoritesHeader(viewModel: viewModel, isEditing: $isEditing)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: Metrics.screenMargin, bottom: 0, trailing: Metrics.screenMargin))
                .listRowSeparator(.hidden)
                FavoritesListContent(viewModel: viewModel)
            }
            // Rows straight on the background with hairlines, like Gasolineras.
            .listStyle(.plain)
            #if os(iOS)
            .environment(\.editMode, .constant(isEditing ? .active : .inactive))
            #endif
            .scrollContentBackground(.hidden)
            .background(ColorTokens.background)
            .refreshable { await viewModel.refresh(force: true) }
            .overlay(alignment: .bottom) {
                if case .updating = viewModel.state { UpdatingPill().padding(.bottom, 12) }
            }
            #if os(iOS)
            .toolbarVisibility(.hidden, for: .navigationBar)
            #endif
            .navigationDestination(isPresented: router.detailPushBinding(on: .favorites)) {
                DetailPane(presentation: .push)
            }
        }
        .task { await viewModel.start() }
    }
}
