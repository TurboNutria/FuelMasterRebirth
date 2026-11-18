import DomainLayer
import Foundation
import Observation

/// The three root layouts (Bear note 02, "Rules"). Chosen from size classes, never the device model.
public enum LayoutMode: String, Sendable {
    /// Portrait iPhone, closed iPhone Duo, narrow iPad window.
    case tabs
    /// Standard iPhones in landscape: list and map side by side, detail as a sheet.
    case sideBySide
    /// iPad, Mac, Plus / Pro Max landscape, open iPhone Duo: map always visible, detail in an inspector.
    case split

    public init(horizontalIsRegular: Bool, verticalIsCompact: Bool) {
        if horizontalIsRegular {
            self = .split
        } else if verticalIsCompact {
            self = .sideBySide
        } else {
            self = .tabs
        }
    }

    /// The map has its own tab only in `.tabs`; the other layouts always show it.
    public var hasMapTab: Bool { self == .tabs }
}

public enum AppTab: String, CaseIterable, Sendable {
    case map, list, favorites, settings, search

    /// Tabs in the order each layout shows them. Large screens drop Mapa (it's always visible).
    public static func tabs(for mode: LayoutMode) -> [AppTab] {
        mode.hasMapTab ? [.map, .list, .favorites, .settings, .search] : [.list, .favorites, .search, .settings]
    }
}

/// Navigation and selection only (Bear note 02, "Review against 06"). Screen state lives in the
/// view models, which the root creates once so they survive layout changes.
@MainActor @Observable
public final class AppRouter {
    public var selectedTab: AppTab
    public var selectedStationID: StationID? {
        didSet { isDetailPresented = selectedStationID != nil }
    }
    /// Stored, because `.inspector(isPresented:)` and `.sheet(isPresented:)` need a binding.
    public var isDetailPresented = false {
        didSet { if !isDetailPresented, selectedStationID != nil { selectedStationID = nil } }
    }
    public private(set) var layoutMode: LayoutMode
    /// The list panel is hidden and the map fills the screen (larger layouts only). Kept when the
    /// layout changes, so it survives rotating and folding.
    public var isPanelCollapsed = false

    public init(selectedTab: AppTab = .map, layoutMode: LayoutMode = .tabs) {
        self.selectedTab = selectedTab
        self.layoutMode = layoutMode
    }

    public var visibleTabs: [AppTab] { AppTab.tabs(for: layoutMode) }

    /// Whether the panel beside the map is on screen.
    public var showsPanel: Bool { !layoutMode.hasMapTab && !isPanelCollapsed }

    /// Whether the map carries its own fuel and filter menus: when no list is beside it.
    public var showsMapMenus: Bool { !showsPanel }

    /// Whether a tab's own stack pushes the detail: only in tabs.
    public func pushesDetail(on tab: AppTab) -> Bool {
        isDetailPresented && selectedTab == tab && layoutMode == .tabs
    }

    /// Whether the detail opens over the map (a sheet, or an inspector on wide screens), so the
    /// panel keeps showing the tab that's selected. Pushing it into the panel replaced whatever
    /// was there, Ajustes included (QA on the Duo, 2026-10-29).
    public var presentsDetailBesideMap: Bool {
        isDetailPresented && layoutMode != .tabs
    }

    public func select(_ station: StationID?) {
        selectedStationID = station
    }

    /// Rotating, unfolding the Duo or resizing a window swaps the root view; this keeps the
    /// selection meaningful in the new layout.
    public func layoutDidChange(to mode: LayoutMode) {
        guard mode != layoutMode else { return }
        layoutMode = mode
        if !mode.hasMapTab, selectedTab == .map {
            // The map is always on screen in the larger layouts, so its tab gives way to the list.
            selectedTab = .list
        } else if mode.hasMapTab, selectedStationID != nil, selectedTab != .list, selectedTab != .favorites {
            // Back to tabs with a station open: Gasolineras pushes its detail (note 02).
            selectedTab = .list
        }
    }
}
