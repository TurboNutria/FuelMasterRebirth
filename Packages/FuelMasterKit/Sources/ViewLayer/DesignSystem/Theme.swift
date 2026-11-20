import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// The look settings (accent, price scale, number format) live in DesignTokens, shared with the
/// widgets and the watch. RootView sets them from Settings (U6).
extension EnvironmentValues {
    /// Top safe area that only the status corner needs (the unfolded Duo in portrait), so the
    /// left-hand controls can use it. Zero everywhere else.
    @Entry var freeTopInset: CGFloat = 0
}

/// Type styles from the canvas "Fundamentos". Everything scales with Dynamic Type.
extension Font {
    /// Screen titles: "Gasolineras" (34 pt, rounded, heavy).
    static let screenTitle = Font.system(.largeTitle, design: .rounded, weight: .heavy)
    static let rowTitle = Font.system(.callout, weight: .semibold)
    static let rowDetail = Font.footnote
}

extension LocalizedStringResource.BundleDescription {
    /// This package target's bundle, which holds the View layer's String Catalog.
    static var viewLayer: Self { .atURL(Bundle.module.bundleURL) }
}
