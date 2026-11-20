import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

extension Font {
    /// Condensed, like the sign's Barlow Condensed (the system's condensed width stands in for it).
    static func board(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        .system(size: size, weight: weight).width(.condensed)
    }
}
