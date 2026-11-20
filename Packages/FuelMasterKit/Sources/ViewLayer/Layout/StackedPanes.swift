import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// The open Duo turned a quarter, with the fold running across (flat, or standing on a table): the
/// map above the fold to look at, the panel below it to touch (Bear note 02, table pose). The
/// detail opens over the map's half, so the list stays in reach. Hiding the panel gives the map
/// the whole screen.
struct StackedPanes: View {
    @Bindable var router: AppRouter
    /// The fold, in this view's space.
    let fold: CGRect

    @State private var height: CGFloat = 0
    @State private var freeTopInset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            MapPane()
                .environment(\.freeTopInset, freeTopInset)
                .frame(maxHeight: .infinity)
                .accessibilityHidden(router.presentsDetailBesideMap && !router.isPanelCollapsed)
                .overlay(alignment: .top) {
                    DetailPaneOverlay(edge: .bottom)
                        .frame(height: max(0, fold.minY))
                }
            PanelColumn(router: router)
                // Clear of the fold itself while it's bent.
                .padding(.top, fold.height)
                .frame(height: panelHeight)
                .frame(height: router.isPanelCollapsed ? 0 : panelHeight, alignment: .top)
                .clipped()
                .allowsHitTesting(!router.isPanelCollapsed)
                .accessibilityHidden(router.isPanelCollapsed)
        }
        .background(ColorTokens.background)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        // The map spans the top, so its left-hand controls can rise beside the status corner.
        .onGeometryChange(for: CGFloat.self) { proxy in
            CollapsiblePanes.freeTopInset(in: proxy, leftWidth: proxy.size.width / 2)
        } action: { freeTopInset = $0 }
    }

    private var panelHeight: CGFloat { max(0, height - fold.minY) }
}
