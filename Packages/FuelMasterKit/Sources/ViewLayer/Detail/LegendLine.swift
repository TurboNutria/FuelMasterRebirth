import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// A horizontal line for the dashed legend swatch.
struct LegendLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}
