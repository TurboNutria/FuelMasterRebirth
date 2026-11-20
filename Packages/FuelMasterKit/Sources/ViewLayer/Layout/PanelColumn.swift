import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

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
                .padding(.horizontal, Metrics.screenMargin)
                .padding(.top, 16)
                .padding(.bottom, 12)
            TabContent(tab: router.selectedTab)
        }
        .background(ColorTokens.background)
    }
}
