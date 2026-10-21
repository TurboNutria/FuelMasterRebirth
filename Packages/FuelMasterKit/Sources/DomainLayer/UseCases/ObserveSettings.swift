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

    /// Reads, changes and saves in one step, so callers only describe the change.
    public func callAsFunction(_ change: @Sendable (inout Settings) -> Void) async {
        var current = await settings.current()
        change(&current)
        await settings.update(current)
    }
}
