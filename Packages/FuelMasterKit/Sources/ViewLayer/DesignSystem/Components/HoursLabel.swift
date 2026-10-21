import DomainLayer
import SwiftUI
import ViewModelLayer

/// Today's opening hours: green when open, grey with a moon when closed, plain when unreadable.
/// VoiceOver reads the status instead of the range ("Cerrada, abre a las 7:30").
public struct HoursLabel: View {
    let summary: HoursSummary

    public init(_ summary: HoursSummary) {
        self.summary = summary
    }

    public var body: some View {
        HStack(spacing: 3) {
            if isClosed {
                Image(systemName: "moon.fill").imageScale(.small)
            }
            Text(visibleText)
        }
        .fontWeight(isUnknown ? .regular : .semibold)
        .foregroundStyle(color)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenText)
    }

    private var isClosed: Bool {
        if case .closed = summary.status { return true }
        return false
    }

    private var isUnknown: Bool { summary.status == .unknown }

    private var color: Color {
        switch summary.status {
        case .alwaysOpen, .open: ColorTokens.open
        case .closed: ColorTokens.closed
        case .unknown: ColorTokens.textSecondary
        }
    }

    private var visibleText: String {
        switch summary.today {
        case .allDay: String(localized: "24 h", bundle: .module, comment: "Open all day, short")
        case .ranges(let ranges): ranges
        case .closedAllDay: String(localized: "Cerrada hoy", bundle: .module)
        case .unknown(let raw): raw
        }
    }

    /// Also used by StationRow to build its single VoiceOver sentence.
    var spokenText: String {
        switch summary.status {
        case .alwaysOpen:
            return String(localized: "Abierta 24 horas", bundle: .module)
        case .open:
            if summary.today == .allDay { return String(localized: "Abierta 24 horas", bundle: .module) }
            guard let time = summary.nextChange else { return String(localized: "Abierta", bundle: .module) }
            return String(localized: "Abierta, cierra a las \(time)", bundle: .module)
        case .closed:
            guard let time = summary.nextChange else { return String(localized: "Cerrada", bundle: .module) }
            return String(localized: "Cerrada, abre a las \(time)", bundle: .module)
        case .unknown:
            return String(localized: "Horario: \(visibleText)", bundle: .module)
        }
    }
}
