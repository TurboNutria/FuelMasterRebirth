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
        CollapsiblePanes(router: router, panelWidth: 320)
    }
}

/// The panel and the map as two plain panes, with the detail as a sheet. Hiding the panel clips it
/// to nothing rather than removing it, so its scroll position and search text survive.
struct CollapsiblePanes: View {
    @Bindable var router: AppRouter
    let panelWidth: CGFloat

    @State private var freeTopInset: CGFloat = 0

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
        }
        .background(ColorTokens.background)
        .onGeometryChange(for: CGFloat.self) { [panelWidth] proxy in
            Self.freeTopInset(in: proxy, panelWidth: panelWidth)
        } action: { freeTopInset = $0 }
        .sheet(isPresented: router.detailBesideMapBinding) {
            // Always full height: at half height it showed little more than the name (QA 2026-11-11).
            NavigationStack { DetailPane(presentation: .sheet) }
                .presentationDetents([.large])
        }
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

/// `.split` (iPad, Mac, open Duo): the map is always visible and the tabs switch the left panel.
///
/// Wide screens (iPad, Mac) use a NavigationSplitView with the detail in an inspector. Narrower
/// regular-width screens (the open iPhone Duo, an iPad window in split screen) get two plain panes
/// with the detail as a sheet: there, a 300 pt sidebar plus a 300 pt inspector don't fit, and
/// UIKit's split-view solver ran out of memory and crashed (QA on the Duo, 2026-10-29). On a fold
/// the panes meet at the hinge; system sheets keep clear of it.
struct SplitRootView: View {
    /// Room for sidebar, inspector and some map (300 + 300 + 300).
    static let inspectorWidth: CGFloat = 900

    @Bindable var router: AppRouter

    @State private var fold: CGRect?
    @State private var width: CGFloat = 0

    var body: some View {
        Group {
            if usesTwoPanes {
                CollapsiblePanes(router: router, panelWidth: panelWidth)
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
        if let fold { return fold.minX }
        return max(300, (width / 2).rounded())
    }
}

/// Where a vertical fold crosses this view (the open iPhone Duo's hinge), from the system's
/// reserved regions. Nil on iOS 26 and on screens without one.
struct FoldReader: View {
    @Binding var fold: CGRect?

    var body: some View {
        Color.clear
            .onGeometryChange(for: CGRect?.self) { proxy in
                let local = proxy.frame(in: .local)
                #if DEBUG
                // `-FMFakeFold YES` pretends there's a hinge down the middle, to try the open-Duo
                // layout on an iPad simulator.
                if UserDefaults.standard.bool(forKey: "FMFakeFold") {
                    return CGRect(x: local.midX, y: local.minY, width: 0, height: local.height)
                }
                #endif
                #if os(iOS)
                guard #available(iOS 27.1, *) else { return nil }
                return proxy.reservedRegions(kind: .division)
                    .map { (region: ReservedRegion) in region.frame }
                    // A vertical hinge in the middle third: anything else (a horizontal fold, a
                    // frame in an unexpected space) would make a broken column, so it's ignored.
                    .first { $0.height > $0.width && $0.midX > local.width / 3 && $0.midX < local.width * 2 / 3 }
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
            .glassEffect(.regular, in: .capsule)
        }
    }
}
