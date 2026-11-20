import DesignTokens
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
