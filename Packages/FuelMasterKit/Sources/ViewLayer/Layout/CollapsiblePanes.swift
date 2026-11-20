import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// The panel and the map as two plain panes. Hiding the panel clips it to nothing rather than
/// removing it, so its scroll position and search text survive.
///
/// The detail opens as a sheet, or with `detailInPane` as a pane over the map's half (the open
/// Duo, narrow iPad windows): the list stays usable beside it, so another row swaps the station
/// without closing anything first.
struct CollapsiblePanes: View {
    @Bindable var router: AppRouter
    let panelWidth: CGFloat
    let detailInPane: Bool

    @State private var freeTopInset: CGFloat = 0
    @State private var width: CGFloat = 0

    var body: some View {
        HStack(spacing: 0) {
            PanelColumn(router: router)
                .frame(width: panelWidth)
                .frame(width: router.isPanelCollapsed ? 0 : panelWidth, alignment: .trailing)
                .clipped()
                .allowsHitTesting(!router.isPanelCollapsed)
                .accessibilityHidden(router.isPanelCollapsed)
                .ignoresSafeArea(.container, edges: freeTopInset > 0 ? .top : [])
            MapPane()
                .environment(\.freeTopInset, freeTopInset)
                .accessibilityHidden(detailCoversMap)
        }
        // The map's half even with the panel hidden, so part of the map stays in view.
        .overlay(alignment: .trailing) {
            if detailInPane {
                DetailPaneOverlay(edge: .leading)
                    .frame(width: max(0, width - panelWidth))
            }
        }
        .background(ColorTokens.background)
        .onGeometryChange(for: CGFloat.self) { [panelWidth] proxy in
            Self.freeTopInset(in: proxy, leftWidth: panelWidth)
        } action: { freeTopInset = $0 }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .sheet(isPresented: detailSheetPresented) {
            // Always full height: at half height it showed little more than the name (QA 2026-11-11).
            NavigationStack { DetailPane(presentation: .sheet) }
                .presentationDetents([.large])
        }
    }

    private var detailCoversMap: Bool {
        detailInPane && router.presentsDetailBesideMap && !router.isPanelCollapsed
    }

    private var detailSheetPresented: Binding<Bool> {
        detailInPane ? .constant(false) : router.detailBesideMapBinding
    }

    /// The unfolded Duo reserves about 78 pt across the top, but its status and camera only sit in
    /// the right-hand corner; that band left blank above the panel, or above the map's controls
    /// with the panes stacked, was jarring (QA 2026-10-30, 2026-11-19). Other layouts have far less
    /// (iPad 24, landscape 0), and keep theirs. `leftWidth` is the part of the top edge that would use
    /// the band: the panel, or the map's left-hand controls.
    nonisolated static func freeTopInset(in proxy: GeometryProxy, leftWidth: CGFloat) -> CGFloat {
        let top = proxy.safeAreaInsets.top
        #if DEBUG
        // `-FMFakeFreeTop YES` tries this on an iPad simulator, with `-FMFakeFold YES`.
        if UserDefaults.standard.bool(forKey: "FMFakeFreeTop") { return top }
        #endif
        guard top > 44 else { return 0 }
        #if os(iOS)
        if #available(iOS 27.1, *) {
            // If the camera is over that part (the phone turned the other way up), keep the inset.
            // A band as wide as half the screen says nothing about which side is free.
            let panelIsCovered = proxy.reservedRegions(kind: .occlusion).contains { (region: ReservedRegion) in
                region.frame.width < proxy.size.width / 2 && region.frame.minX < leftWidth
            }
            if panelIsCovered { return 0 }
        }
        #endif
        return top
    }
}
