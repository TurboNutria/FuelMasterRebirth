import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

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
