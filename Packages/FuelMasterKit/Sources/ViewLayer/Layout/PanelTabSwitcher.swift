import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

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
