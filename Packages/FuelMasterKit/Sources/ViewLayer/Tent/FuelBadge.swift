import DesignTokens
import DomainLayer
import SwiftUI
import ViewModelLayer

/// The EU fuel label: B7 / XTL in a diamond for diesel, E5 / E10 in a circle for petrol, a square
/// for gas and AdBlue.
struct FuelBadge: View {
    let product: Product
    let scale: CGFloat

    var body: some View {
        let label = Text(verbatim: code).font(.board((code.count > 2 ? 14 : 19) * scale, .bold))
        switch shape {
        case .diamond:
            label
                .frame(width: 50 * scale, height: 50 * scale)
                .background {
                    Rectangle().strokeBorder(TentColors.ink, lineWidth: 3 * scale)
                        .frame(width: 38 * scale, height: 38 * scale)
                        .rotationEffect(.degrees(45))
                }
        case .circle:
            label
                .frame(width: 50 * scale, height: 50 * scale)
                .overlay { Circle().strokeBorder(TentColors.ink, lineWidth: 3 * scale) }
        case .square:
            label
                .frame(width: 50 * scale, height: 50 * scale)
                .overlay { RoundedRectangle(cornerRadius: 4 * scale).strokeBorder(TentColors.ink, lineWidth: 3 * scale) }
        }
    }

    private enum Shape { case diamond, circle, square }

    private var shape: Shape {
        switch product {
        case .diesel, .dieselPremium, .renewableDiesel: .diamond
        case .petrol95E5, .petrol95Premium, .petrol98E5: .circle
        case .lpg, .cng, .lng, .adBlue: .square
        }
    }

    private var code: String {
        switch product {
        case .diesel, .dieselPremium: "B7"
        case .renewableDiesel: "XTL"
        case .petrol95E5, .petrol95Premium, .petrol98E5: "E5"
        case .lpg: "LPG"
        case .cng: "CNG"
        case .lng: "LNG"
        case .adBlue: "AdB"
        }
    }
}
