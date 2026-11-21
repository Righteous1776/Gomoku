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
        scrollUntilHittable(advanced, in: app)
        advanced.tap()

        let learning = app.descendants(matching: .any)["gomoku.training.learning-card"]
        scrollUntilHittable(learning, in: app)
        capture(app, named: "Gomoku-instrument-training-expanded")
        scrollUntilHittable(advanced, in: app, swipeUp: false)
        advanced.tap()
        XCTAssertFalse(learning.exists)
    }

    func testInstrumentDayAndNightModesAreSelectable() {
        let app = XCUIApplication()
        app.launch()
        let advanced = app.buttons["gomoku.training.advanced.toggle"]
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

    /// LazyVStack does not create off-screen elements until scrolling.
    /// The original test queried .exists before scrolling, so its snapshot
    /// check could fail without any defect in the actual iPhone UI.
    private func scrollUntilHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        swipeUp: Bool = true
    ) {
        for _ in 0..<15 {
            if element.isHittable { return }
            if swipeUp {
                app.swipeUp()
            } else {
                app.swipeDown()
            }
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
