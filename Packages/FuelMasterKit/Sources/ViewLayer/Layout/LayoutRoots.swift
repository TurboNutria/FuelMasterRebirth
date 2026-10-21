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
    }
}

/// `.sideBySide` (standard iPhones in landscape): list column at a fixed width and the map
/// filling the rest; detail opens as a sheet. ArrangementView takes over on iOS 27.1+ in U7.
struct SideBySideRootView: View {
    @Bindable var router: AppRouter

    var body: some View {
        HStack(spacing: 0) {
            PanelColumn(router: router)
                .frame(width: 320)
            Divider()
            MapPane()
        }
        .sheet(isPresented: $router.isDetailPresented) {
            DetailPlaceholder()
                .presentationDetents([.medium, .large])
        }
    }
}

/// `.split` (iPad, Mac, open Duo): the map is always visible, the tabs switch the left panel and
/// detail is an inspector.
struct SplitRootView: View {
    @Bindable var router: AppRouter

    var body: some View {
        NavigationSplitView {
            PanelColumn(router: router)
                .navigationSplitViewColumnWidth(min: 300, ideal: 360, max: 420)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            MapPane()
                .inspector(isPresented: $router.isDetailPresented) {
                    DetailPlaceholder()
                        .inspectorColumnWidth(min: 300, ideal: 340, max: 400)
                }
        }
    }
}

/// The left panel of the two larger layouts: a glass tab switcher above the selected screen.
struct PanelColumn: View {
    @Bindable var router: AppRouter

    var body: some View {
        TabContent(tab: router.selectedTab)
            .safeAreaInset(edge: .top, spacing: 0) {
                PanelTabSwitcher(tabs: router.visibleTabs, selection: $router.selectedTab)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
    }
}

/// Icon-only glass capsule matching the canvas tab bar, for layouts without a TabView.
struct PanelTabSwitcher: View {
    let tabs: [AppTab]
    @Binding var selection: AppTab

    @Environment(\.accentColors) private var accent

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 4) {
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
            .padding(4)
            .glassEffect(.regular, in: .capsule)
        }
    }
}
