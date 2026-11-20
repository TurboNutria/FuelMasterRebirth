import DomainLayer
import Foundation
import Observation

/// The accent and price scale the watch draws with, following the iPhone's settings as they
/// arrive (Bear note 06). The watch is always dark, so appearance doesn't apply.
@MainActor @Observable
public final class WatchLookViewModel {
    public private(set) var accent: AccentChoice = Settings.default.accent
    public private(set) var priceScale: PriceScale = Settings.default.priceScale

    private let observeSettings: ObserveSettings

    public init(observeSettings: ObserveSettings) {
        self.observeSettings = observeSettings
    }

    /// Runs while the app is open.
    public func start() async {
        let changes = await observeSettings()
        apply(await observeSettings.current())
        for await settings in changes { apply(settings) }
    }

    private func apply(_ settings: Settings) {
        if accent != settings.accent { accent = settings.accent }
        if priceScale != settings.priceScale { priceScale = settings.priceScale }
    }
}
