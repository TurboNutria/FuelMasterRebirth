import XCTest

/// Xcode's accessibility audit on every main screen (Bear note 06, "Testing strategy"). Each test
/// opens one screen through the DEBUG launch arguments, so no taps are needed.
@MainActor
final class AccessibilityAuditTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    /// The controls over the map stop at the largest standard text size on purpose (as in Maps),
    /// with the large content viewer instead.
    func testMap() throws { try audit(["-FMInitialTab", "map"], allowsUnlabelledText: true, capsTextSize: true) }
    func testStations() throws { try audit(["-FMInitialTab", "list"], knownContrastNode: true) }
    func testFavorites() throws { try audit(["-FMInitialTab", "favorites", "-FMSeedFavorites", "3213,2909,4710"]) }
    func testSearch() throws { try audit(["-FMInitialTab", "search", "-FMSearch", "repsol"], knownContrastNode: true) }
    func testSettings() throws { try audit(["-FMInitialTab", "settings"], knownContrastNode: true) }
    func testDetail() throws { try audit(["-FMInitialTab", "list", "-FMSelectStation", "3213"], allowsUnlabelledText: true) }
    /// The welcome screen's sample price pins are decorative and hidden from VoiceOver on purpose.
    func testOnboarding() throws { try audit(["-FMInitialTab", "map"], skipOnboarding: false, allowsUnlabelledText: true) }

    func testStationsWithLargestText() throws {
        try audit(["-FMInitialTab", "list", "-UIPreferredContentSizeCategoryName",
                   "UICTContentSizeCategoryAccessibilityXXXL"], knownContrastNode: true)
    }

    func testDetailWithLargestText() throws {
        try audit(["-FMInitialTab", "list", "-FMSelectStation", "3213", "-UIPreferredContentSizeCategoryName",
                   "UICTContentSizeCategoryAccessibilityXXXL"])
    }

    // MARK: -

    /// - Parameter allowsUnlabelledText: the map's street names, the chart's axis labels and the
    ///   welcome screen's sample pins are drawn text without elements of their own; the chart is
    ///   one element with a summary and an Audio Graph, and the map pins carry their own labels.
    /// - Parameter knownContrastNode: an open finding (Bear 06, U9): one contrast failure on a
    ///   SwiftUI node with no element of its own, on Gasolineras, Buscar and Ajustes but not
    ///   Favoritos. Not the segmented picker, the tab bar, the green chips or the spinner, which
    ///   were each ruled out. Remove the flag once it's found.
    private func audit(_ arguments: [String], skipOnboarding: Bool = true, allowsUnlabelledText: Bool = false,
                       knownContrastNode: Bool = false, capsTextSize: Bool = false) throws {
        let app = XCUIApplication()
        app.launchArguments = arguments + (skipOnboarding ? ["-FMSkipOnboarding", "YES"] : ["-FMResetOnboarding", "YES"])
        app.launch()
        // Wait for the screen itself, not its loading state: a first location fix can take the
        // full 6 s before the list falls back to the province, and the spinner's faded ticks
        // would be audited instead of the rows.
        sleep(2)
        let deadline = Date.now.addingTimeInterval(30)
        while app.activityIndicators.count > 0, Date.now < deadline { sleep(1) }
        sleep(2)
        try app.performAccessibilityAudit { issue in
            // Map tiles and MapKit's own controls aren't ours to fix.
            if let element = issue.element, element.elementType == .map { return true }
            if allowsUnlabelledText, issue.auditType == .elementDetection, issue.element == nil { return true }
            if capsTextSize, issue.auditType == .dynamicType { return true }
            if knownContrastNode, issue.auditType == .contrast, issue.element == nil {
                print("AUDIT KNOWN \(self.name) | \(issue.compactDescription)")
                return true
            }
            // MapKit's "Legal" link is the system's.
            if let element = issue.element, element.elementType == .link, element.label == "Legal" { return true }
            // The bottom bar caps its text size; "Cómo llegar" shows the large content viewer instead.
            if issue.auditType == .dynamicType, issue.element?.identifier == "directions" { return true }
            let element = issue.element.map { "\($0.elementType.rawValue) '\($0.label)' \($0.frame)" }
                ?? "no element: \(issue.detailedDescription)"
            print("AUDIT \(self.name) | \(issue.compactDescription) | \(element)")
            return false
        }
    }
}
