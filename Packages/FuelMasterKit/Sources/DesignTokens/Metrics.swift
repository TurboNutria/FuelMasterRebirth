import CoreGraphics

/// Spacing and sizes the screens share, so one change keeps them in step.
public enum Metrics {
    /// The side margin of every full-width screen: lists, Buscar, the detail, onboarding.
    public static let screenMargin: CGFloat = 20
    /// Between the sections of a page (the detail's price, chart and other fuels; onboarding).
    public static let sectionSpacing: CGFloat = 32
    /// How far an empty or failed state sits below the screen's header.
    public static let emptyStateTop: CGFloat = 60
    /// The screen's one large price (detail, Favoritos' best, the peek) at the default text
    /// size. Use it with `@ScaledMetric(relativeTo: .largeTitle)` so it grows with Dynamic Type.
    public static let heroPrice: CGFloat = 44
}
