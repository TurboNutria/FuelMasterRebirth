import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// `.split` (iPad, Mac, open Duo): the map is always visible and the tabs switch the panel.
///
/// Wide screens (iPad, Mac) use a NavigationSplitView with the detail in an inspector. Narrower
/// regular-width screens (the open iPhone Duo, an iPad window in split screen) get two plain panes
/// with the detail as a pane over the map's half: there, a 300 pt sidebar plus a 300 pt inspector
/// don't fit, and UIKit's split-view solver ran out of memory and crashed (QA on the Duo,
/// 2026-10-29). On a fold the panes meet at the hinge: side by side when it runs down the screen,
/// stacked when the Duo is turned and it runs across.
struct SplitRootView: View {
    /// Room for sidebar, inspector and some map (300 + 300 + 300).
    static let inspectorWidth: CGFloat = 900

    @Bindable var router: AppRouter

    @State private var fold: FoldLine?
    @State private var width: CGFloat = 0

    var body: some View {
        Group {
            if let fold, fold.axis == .horizontal {
                StackedPanes(router: router, fold: fold.frame)
            } else if usesTwoPanes {
                CollapsiblePanes(router: router, panelWidth: panelWidth, detailInPane: true)
            } else {
                NavigationSplitView(columnVisibility: columnVisibility) {
                    PanelColumn(router: router)
                        .navigationSplitViewColumnWidth(min: 340, ideal: 380, max: 440)
                        .toolbar(removing: .sidebarToggle)
                } detail: {
                    MapPane()
                        .inspector(isPresented: router.detailBesideMapBinding) {
                            NavigationStack { DetailPane(presentation: .inspector) }
                                .inspectorColumnWidth(min: 300, ideal: 340, max: 400)
                        }
                }
            }
        }
        // Read on the container, whose size the panes can't change (pinning the split view's
        // column to a measured width made it re-lay out forever).
        .background { FoldReader(fold: $fold) }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }

    /// The sidebar follows the same collapsed state as the plain panes.
    private var columnVisibility: Binding<NavigationSplitViewVisibility> {
        Binding(get: { router.isPanelCollapsed ? .detailOnly : .all },
                set: { router.isPanelCollapsed = $0 == .detailOnly })
    }

    /// Before the first measurement the width is 0, which would pick the two panes for a frame;
    /// that's harmless, and it never starts a split view that can't fit.
    private var usesTwoPanes: Bool { fold != nil || width < Self.inspectorWidth }

    /// At the hinge when there is one, otherwise half, and never narrower than the list needs.
    private var panelWidth: CGFloat {
        if let fold, fold.axis == .vertical { return fold.frame.minX }
        return max(300, (width / 2).rounded())
    }
}
