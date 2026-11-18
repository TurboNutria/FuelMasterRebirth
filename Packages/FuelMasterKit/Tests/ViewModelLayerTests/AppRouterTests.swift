import DomainLayer
import Testing
import ViewModelLayer

@Suite("Layout mode")
struct LayoutModeTests {
    @Test func regularWidthIsSplit() {
        // iPad, Mac, Pro Max landscape, open iPhone Duo.
        #expect(LayoutMode(horizontalIsRegular: true, verticalIsCompact: false) == .split)
        #expect(LayoutMode(horizontalIsRegular: true, verticalIsCompact: true) == .split)
    }

    @Test func compactHeightIsSideBySide() {
        #expect(LayoutMode(horizontalIsRegular: false, verticalIsCompact: true) == .sideBySide)
    }

    @Test func compactWidthIsTabs() {
        // Portrait iPhone, closed Duo, narrow iPad window.
        #expect(LayoutMode(horizontalIsRegular: false, verticalIsCompact: false) == .tabs)
    }

    @Test func largeLayoutsDropTheMapTab() {
        #expect(AppTab.tabs(for: .tabs) == [.map, .list, .favorites, .settings, .search])
        #expect(AppTab.tabs(for: .split) == [.list, .favorites, .search, .settings])
    }
}

@Suite("App router")
@MainActor
struct AppRouterTests {
    let station = StationID("4375")

    @Test func selectingAStationPresentsItsDetail() {
        let router = AppRouter()
        router.select(station)
        #expect(router.isDetailPresented)
        router.isDetailPresented = false
        #expect(router.selectedStationID == nil)
    }

    @Test func detailRemembersWhereItCameFrom() {
        let router = AppRouter()
        router.select(station, from: .map)
        #expect(router.detailOrigin == .map)
        router.select(StationID("2909"))
        #expect(router.detailOrigin == .list)
        router.open(StationLink.url(for: station))
        #expect(router.detailOrigin == .list)
    }

    @Test func showOnMapInTabsClosesTheDetailAndMarksThePin() {
        let router = AppRouter(selectedTab: .list)
        router.select(station)
        router.showOnMap(station, keepsDetail: false)
        #expect(router.selectedTab == .map)
        #expect(router.selectedStationID == nil)
        #expect(router.highlightedStationID == station)
        // Picking another station drops the mark.
        router.select(StationID("2909"), from: .map)
        router.isDetailPresented = false
        #expect(router.highlightedStationID == nil)
    }

    @Test func showOnMapBesideTheMapKeepsTheInspector() {
        let router = AppRouter(selectedTab: .favorites, layoutMode: .split)
        router.select(station)
        router.showOnMap(station, keepsDetail: true)
        #expect(router.selectedTab == .favorites)
        #expect(router.selectedStationID == station)
    }

    @Test func mapTabGivesWayToTheListOnLargeScreens() {
        let router = AppRouter(selectedTab: .map)
        router.layoutDidChange(to: .split)
        #expect(router.selectedTab == .list)
        #expect(router.visibleTabs == [.list, .favorites, .search, .settings])
    }

    @Test func selectionSurvivesUnfoldingAndFolding() {
        let router = AppRouter(selectedTab: .favorites)
        router.select(station)
        router.layoutDidChange(to: .split)
        #expect(router.selectedStationID == station)
        #expect(router.selectedTab == .favorites)
        router.layoutDidChange(to: .tabs)
        #expect(router.selectedStationID == station)
        #expect(router.isDetailPresented)
        #expect(router.selectedTab == .favorites)
    }

    @Test func backToTabsWithAStationOpenShowsGasolineras() {
        let router = AppRouter(selectedTab: .search, layoutMode: .split)
        router.select(station)
        router.layoutDidChange(to: .tabs)
        #expect(router.selectedTab == .list)
    }

    @Test func tabStaysWhenNothingIsSelected() {
        let router = AppRouter(selectedTab: .settings, layoutMode: .split)
        router.layoutDidChange(to: .tabs)
        #expect(router.selectedTab == .settings)
    }
}

@Suite("Detail placement")
@MainActor
struct DetailPlacementTests {
    let station = StationID("3213")

    @Test func tabsPushOnTheSelectedTabOnly() {
        let router = AppRouter(selectedTab: .favorites, layoutMode: .tabs)
        router.select(station)
        #expect(router.pushesDetail(on: .favorites))
        #expect(!router.pushesDetail(on: .list))
        #expect(!router.presentsDetailBesideMap)
    }

    @Test func splitOpensOverTheMapAndKeepsThePanelsTab() {
        let router = AppRouter(selectedTab: .settings, layoutMode: .split)
        router.select(station)
        #expect(router.presentsDetailBesideMap)
        #expect(!router.pushesDetail(on: .settings))
        #expect(router.selectedTab == .settings)
    }

    @Test func sideBySideUsesASheet() {
        let router = AppRouter(selectedTab: .list, layoutMode: .sideBySide)
        router.select(station)
        #expect(router.presentsDetailBesideMap)
        #expect(!router.pushesDetail(on: .list))
    }
}

@Suite("List panel")
@MainActor
struct ListPanelTests {
    @Test func collapsingHidesThePanelAndGivesTheMapItsMenus() {
        let router = AppRouter(selectedTab: .list, layoutMode: .sideBySide)
        #expect(router.showsPanel)
        #expect(!router.showsMapMenus)

        router.isPanelCollapsed = true
        #expect(!router.showsPanel)
        #expect(router.showsMapMenus)
    }

    @Test func tabsHaveNoPanelAndTheMapKeepsItsMenus() {
        let router = AppRouter(selectedTab: .map, layoutMode: .tabs)
        #expect(!router.showsPanel)
        #expect(router.showsMapMenus)
    }

    @Test func collapsedSurvivesTheLayoutChanging() {
        let router = AppRouter(selectedTab: .list, layoutMode: .sideBySide)
        router.isPanelCollapsed = true
        router.layoutDidChange(to: .tabs)
        router.layoutDidChange(to: .split)
        #expect(router.isPanelCollapsed)
        #expect(!router.showsPanel)
    }

    @Test func aStationStillOpensOverTheCollapsedMap() {
        let router = AppRouter(selectedTab: .list, layoutMode: .split)
        router.isPanelCollapsed = true
        router.select(StationID("3213"))
        #expect(router.presentsDetailBesideMap)
    }
}
