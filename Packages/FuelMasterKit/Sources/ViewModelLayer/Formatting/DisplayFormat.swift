import DomainLayer
import Foundation

/// Display formatting shared by every screen (Bear note 06, "Formatting, text and accessibility").
/// System format styles with the user's locale; prices always to 3 decimals and in euros only.
public struct DisplayFormat: Sendable {
    public let locale: Locale

    public init(locale: Locale = .autoupdatingCurrent) {
        self.locale = locale
    }

    // MARK: Prices

    /// "1,859": the number on chips, pins and rows, without the currency.
    public func price(_ amount: Decimal) -> String {
        amount.formatted(.number.precision(.fractionLength(3)).locale(locale))
    }

    /// "1,859 €": prices in running text, the detail screen and VoiceOver.
    public func priceWithCurrency(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: "EUR").precision(.fractionLength(3)).locale(locale))
    }

    /// "52,30 €": totals such as a full tank, to cents, rounding halves up as a till does.
    public func money(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: "EUR").precision(.fractionLength(2))
            .rounded(rule: .toNearestOrAwayFromZero).locale(locale))
    }

    // MARK: Distance

    /// "850 m" / "1,4 km", or miles where the device uses imperial road distances.
    public func distance(meters: Double) -> String {
        if locale.measurementSystem == .metric {
            if meters < 1000 {
                let rounded = max(10, (meters / 10).rounded() * 10)
                return Measurement(value: rounded, unit: UnitLength.meters).formatted(style(maxFractionDigits: 0))
            }
            let digits = meters < 100_000 ? 1 : 0
            return Measurement(value: meters / 1000, unit: UnitLength.kilometers).formatted(style(maxFractionDigits: digits))
        }
        let miles = meters / 1609.344
        return Measurement(value: max(0.1, miles), unit: UnitLength.miles).formatted(style(maxFractionDigits: miles < 100 ? 1 : 0))
    }

    /// Up to `maxFractionDigits`, so a whole number reads "3 km" rather than "3,0 km".
    private func style(maxFractionDigits: Int) -> Measurement<UnitLength>.FormatStyle {
        .measurement(width: .abbreviated, usage: .asProvided,
                     numberFormatStyle: .number.precision(.fractionLength(0...maxFractionDigits)))
            .locale(locale)
    }

    // MARK: Time

    /// "Hace 12 min" for the freshness line; anything under a minute reads "Ahora".
    public func relativeTime(_ date: Date, now: Date) -> String {
        relative(date, now: now, capitalization: .beginningOfSentence)
    }

    /// "hace 2 h", for use inside a sentence ("Sin conexión · precios de hace 2 h").
    public func relativeTimeInSentence(_ date: Date, now: Date) -> String {
        relative(date, now: now, capitalization: .middleOfSentence)
    }

    /// `RelativeDateTimeFormatter` rather than `Date.RelativeFormatStyle`, because the format style
    /// always measures against the real clock and tests and previews pass their own `now`.
    private func relative(_ date: Date, now: Date, capitalization: Formatter.Context) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .abbreviated
        formatter.dateTimeStyle = .named
        formatter.formattingContext = capitalization
        let reference = now.timeIntervalSince(date) < 60 ? now : date
        return formatter.localizedString(for: reference, relativeTo: now)
    }

    /// "7:30" or "7:30 am", following the locale's (and the device's) 12/24-hour setting.
    public func time(_ date: Date, timeZone: TimeZone = HoursText.stationTimeZone) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .shortened, locale: locale)
        style.timeZone = timeZone
        return date.formatted(style)
    }
}
