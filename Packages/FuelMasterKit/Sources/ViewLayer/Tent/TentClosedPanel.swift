import DesignTokens
import SwiftUI
import ViewModelLayer

/// A closed station: "CErrAdA" in the LED window, then when it opens again and how far the
/// nearest open one is.
struct TentClosedPanel: View {
    let reopening: TentReopening?
    let nearestOpen: Double?
    let scale: CGFloat

    @Environment(\.displayFormat) private var format

    /// The LED words, translated within the letters seven segments can draw (see
    /// `SevenSegmentText`): "CErrAdA", "CLOSEd".
    static let closedSign = String(localized: "CErrAdA", bundle: .module,
                                   comment: "Seven-segment sign. Only 0-9 A b C d E F H L n O o P r S t U and spaces")

    /// "AbrE 06:00", "OPEn 06:00".
    static func opensSign(_ time: String) -> String {
        String(localized: "AbrE \(time)", bundle: .module,
               comment: "Seven-segment sign with a 24-hour time. Only 0-9 A b C d E F H L n O o P r S t U and spaces")
    }

    var body: some View {
        LEDWindow(scale: scale) {
            SevenSegmentText(text: Self.closedSign, unit: 10 * scale, color: TentColors.closedLED)
        }
        .frame(height: 170 * scale)
        .accessibilityLabel(Text("Cerrada", bundle: .module))
        if let reopening {
            HStack(spacing: 14 * scale) {
                VStack(alignment: .leading, spacing: 4 * scale) {
                    opensLabel(reopening.day)
                        .font(.board(32 * scale, .bold))
                        .textCase(.uppercase)
                        .minimumScaleFactor(0.6)
                    if let nearestOpen {
                        Text("Más cercana abierta: \(format.distance(meters: nearestOpen))", bundle: .module)
                            .font(.board(18 * scale, .semibold))
                            .foregroundStyle(TentColors.inkSecondary)
                    }
                }
                .lineLimit(1)
                .foregroundStyle(TentColors.ink)
                .padding(.horizontal, 22 * scale)
                .frame(width: 300 * scale, alignment: .leading)
                .frame(maxHeight: .infinity)
                .background(TentColors.plate, in: .rect(cornerRadius: 10 * scale))
                LEDWindow(scale: scale) {
                    SevenSegmentText(text: Self.opensSign(reopening.signTime), unit: 7.5 * scale, color: TentColors.closedLED)
                }
                .accessibilityLabel(Text("Abre a las \(reopening.time)", bundle: .module))
            }
            .frame(height: 132 * scale)
            .accessibilityElement(children: .combine)
        }
    }

    private func opensLabel(_ day: TentReopening.Day) -> Text {
        switch day {
        case .today: Text("Abre hoy", bundle: .module)
        case .tomorrow: Text("Abre mañana", bundle: .module)
        case .weekday(let weekday): Text("Abre el \(weekday)", bundle: .module)
        }
    }
}
