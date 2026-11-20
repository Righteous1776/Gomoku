import XCTest

final class InstrumentUITests: XCTestCase {
    func testOriginalConsoleOpensAnalysisAndCanReturnToBoard() {
        let app = XCUIApplication()
        app.launch()

        let console = app.buttons["game.eclipse.identity"]
        XCTAssertTrue(console.waitForExistence(timeout: 15))
        capture(app, named: "Gomoku-instrument-board")
        console.tap()
        let trace = app.navigationBars["ECLIPSE // TRACE"]
        XCTAssertTrue(trace.waitForExistence(timeout: 6))
        capture(app, named: "Gomoku-eclipse-analysis")
        trace.buttons["完成"].tap()
        XCTAssertTrue(console.waitForExistence(timeout: 6))
    }

    func testVeilLinkInstrumentHierarchyAndNativeTrainingFoldout() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["game.eclipse.identity"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["gomoku.match.restart"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["gomoku.instrument.quick-controls"].exists)

        let advanced = app.buttons["gomoku.training.advanced.toggle"]
        XCTAssertTrue(advanced.exists)
        scrollUntilHittable(advanced, in: app)
        advanced.tap()

        let learning = app.descendants(matching: .any)["gomoku.training.learning-card"]
        XCTAssertTrue(learning.waitForExistence(timeout: 6))
        capture(app, named: "Gomoku-instrument-training-expanded")
        advanced.tap()
        XCTAssertFalse(learning.exists)
    }

    func testInstrumentDayAndNightModesAreSelectable() {
        let app = XCUIApplication()
        app.launch()
        let advanced = app.buttons["gomoku.training.advanced.toggle"]
        XCTAssertTrue(advanced.waitForExistence(timeout: 15))
        scrollUntilHittable(advanced, in: app)
        advanced.tap()

        let appearance = app.segmentedControls["gomoku.instrument.appearance"]
        XCTAssertTrue(appearance.exists)
        scrollUntilHittable(appearance, in: app)
        appearance.buttons["浅色"].tap()
        capture(app, named: "Gomoku-instrument-day")
        appearance.buttons["深色"].tap()
        capture(app, named: "Gomoku-instrument-night")
        // Restore the user's follow-system preference after the screenshot test.
        appearance.buttons["自动"].tap()
    }

    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 {
            if element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, "Target must remain reachable by native scrolling")
    }

    private func capture(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
