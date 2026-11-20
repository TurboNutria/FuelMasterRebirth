import Foundation

/// The current settings, then every change (Bear note 07, ObserveSettings / UpdateSettings).
public struct ObserveSettings: Sendable {
    private let settings: any SettingsRepository

    public init(settings: any SettingsRepository) {
        self.settings = settings
    }

    public func current() async -> Settings {
        await settings.current()
    }

    public func callAsFunction() async -> AsyncStream<Settings> {
        await settings.changes()
    }
}

public struct UpdateSettings: Sendable {
    private let settings: any SettingsRepository

    public init(settings: any SettingsRepository) {
        self.settings = settings
    }

    /// Callers only describe the change; the repository applies it to the latest settings in one
    /// step, so two changes made at once (a new fuel, a remembered area) both stick.
    public func callAsFunction(_ change: @Sendable (inout Settings) -> Void) async {
        await settings.update(change)
    }
}
