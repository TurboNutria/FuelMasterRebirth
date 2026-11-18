import DomainLayer
import SwiftUI
import ViewModelLayer

/// `.tabs`: icon-only tab bar, with Buscar as the system search tab. Each tab's name stays its
/// accessibility label.
struct TabRootView: View {
    @Bindable var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            ForEach(AppTab.tabs(for: .tabs), id: \.self) { tab in
                Tab(value: tab, role: tab == .search ? .search : nil) {
                    TabContent(tab: tab)
                } label: {
                    Label { tab.title } icon: { Image(systemName: tab.systemImage) }
                        .labelStyle(.iconOnly)
                }
            }
        }
        #if os(iOS)
        .tabBarMinimizeBehavior(.onScrollDown)
        #endif
        // Gasolineras pushes the detail; the Mapa tab has no stack, so it gets a sheet.
        .sheet(isPresented: mapDetailPresented) {
            // Always full height: at half height it showed little more than the name (QA 2026-11-11).
            NavigationStack { DetailPane(presentation: .sheet) }
                .presentationDetents([.large])
        }
    }

    private var mapDetailPresented: Binding<Bool> {
        Binding(get: { router.isDetailPresented && router.selectedTab == .map },
                set: { router.isDetailPresented = $0 })
    }
}

/// `.sideBySide` (standard iPhones in landscape): list and map side by side, detail as a sheet.
/// Plain panes rather than `ArrangementView`, which has no way to hide a pane from SwiftUI.
struct SideBySideRootView: View {
    @Bindable var router: AppRouter

    var body: some View {
        CollapsiblePanes(router: router, panelWidth: 320, detailInPane: false)
    }
}

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
            Self.freeTopInset(in: proxy, panelWidth: panelWidth)
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

    /// The unfolded Duo in portrait reserves about 78 pt across the top, but its status and camera
    /// only sit in the right-hand corner; that band left blank above the panel was jarring (QA
    /// 2026-10-30). Other panel layouts have far less (iPad 24, landscape 0), and keep theirs.
    private nonisolated static func freeTopInset(in proxy: GeometryProxy, panelWidth: CGFloat) -> CGFloat {
        let top = proxy.safeAreaInsets.top
        #if DEBUG
        // `-FMFakeFreeTop YES` tries this on an iPad simulator, with `-FMFakeFold YES`.
        if UserDefaults.standard.bool(forKey: "FMFakeFreeTop") { return top }
        #endif
        guard top > 44 else { return 0 }
        #if os(iOS)
        if #available(iOS 27.1, *) {
            // If the camera is over the panel (the phone turned the other way up), keep the inset.
            // A band as wide as half the screen says nothing about which side is free.
            let panelIsCovered = proxy.reservedRegions(kind: .occlusion).contains { (region: ReservedRegion) in
                region.frame.width < proxy.size.width / 2 && region.frame.minX < panelWidth
            }
            if panelIsCovered { return 0 }
        }
        #endif
        return top
    }
}

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

/// The open Duo turned a quarter, with the fold running across (flat, or standing on a table): the
/// map above the fold to look at, the panel below it to touch (Bear note 02, table pose). The
/// detail opens over the map's half, so the list stays in reach. Hiding the panel gives the map
/// the whole screen.
struct StackedPanes: View {
    @Bindable var router: AppRouter
    /// The fold, in this view's space.
    let fold: CGRect

    @State private var height: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            MapPane()
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
    }

    private var panelHeight: CGFloat { max(0, height - fold.minY) }
}

/// The detail as a pane of its own over the map's part of the screen, with a line on the `edge`
/// it shares with the panel. Empty while no station is open.
struct DetailPaneOverlay: View {
    let edge: Edge

    @Environment(AppRouter.self) private var router

    var body: some View {
        ZStack {
            if router.presentsDetailBesideMap {
                NavigationStack { DetailPane(presentation: .pane) }
                    .overlay(alignment: Alignment(horizontal: edge == .leading ? .leading : .center,
                                                  vertical: edge == .bottom ? .bottom : .center)) {
                        ColorTokens.separator
                            .frame(width: edge == .leading ? 1 : nil, height: edge == .bottom ? 1 : nil)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                    }
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: router.presentsDetailBesideMap)
    }
}

/// Where the open iPhone Duo's fold crosses this view, from the system's reserved regions. Nil on
/// iOS 26 and on screens without one.
struct FoldReader: View {
    @Binding var fold: FoldLine?

    var body: some View {
        Color.clear
            .onGeometryChange(for: FoldLine?.self) { proxy in
                let size = proxy.size
                #if DEBUG
                // `-FMFakeFold YES` pretends there's a hinge down the middle, to try the open-Duo
                // layout on an iPad simulator; `-FMFakeFoldAcross YES` turns it a quarter.
                if UserDefaults.standard.bool(forKey: "FMFakeFold") {
                    if UserDefaults.standard.bool(forKey: "FMFakeFoldAcross") {
                        return FoldLine(frame: CGRect(x: 0, y: size.height / 2, width: size.width, height: 0),
                                        axis: .horizontal)
                    }
                    return FoldLine(frame: CGRect(x: size.width / 2, y: 0, width: 0, height: size.height),
                                    axis: .vertical)
                }
                #endif
                #if os(iOS)
                guard #available(iOS 27.1, *) else { return nil }
                // Inactive ones too: opened flat, the fold has no thickness but stays where it was,
                // so bending and flattening the phone keeps the same layout.
                let regions = proxy.reservedRegions(kind: .division, options: .includeInactive)
                    .map { (region: ReservedRegion) in region.frame }
                return FoldLine(regions: regions, in: size)
                #else
                return nil
                #endif
            } action: { fold = $0 }
    }
}

/// The left panel of the two larger layouts: a glass tab switcher above the selected screen.
struct PanelColumn: View {
    @Bindable var router: AppRouter

    var body: some View {
        // Stacked rather than a safe-area inset, so the screen's title can't end up under the
        // switcher.
        VStack(spacing: 0) {
            PanelTabSwitcher(tabs: router.visibleTabs, selection: $router.selectedTab)
                // Room above and below: on the open Duo there's no top safe area, so it hugged the
                // edge and the screen title (QA 2026-10-29).
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
            TabContent(tab: router.selectedTab)
        }
        .background(ColorTokens.background)
    }
}

/// Icon-only glass capsule matching the canvas tab bar, for layouts without a TabView.
struct PanelTabSwitcher: View {
    let tabs: [AppTab]
    @Binding var selection: AppTab

    @Environment(\.accentColors) private var accent

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 6) {
                ForEach(tabs, id: \.self) { tab in
                    Button {
                        selection = tab
                    } label: {
                        Image(systemName: tab.systemImage)
                            .font(.title3)
                            .symbolVariant(selection == tab ? .fill : .none)
                            .foregroundStyle(selection == tab ? accent.tint : ColorTokens.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background {
                                if selection == tab { Capsule().fill(accent.fill.opacity(0.18)) }
                            }
                            .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.title)
                    .accessibilityAddTraits(selection == tab ? [.isSelected] : [])
                }
            }
            .padding(6)
            // Responds to touch like the system tab bar it stands in for.
            .glassEffect(.regular.interactive(), in: .capsule)
        }
    }
}
