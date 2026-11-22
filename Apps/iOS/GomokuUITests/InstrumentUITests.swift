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

    func testAlwaysAvailableVeilLinkThinkingVisualizationAndFoldableInstruments() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["game.eclipse.identity"].waitForExistence(timeout: 15))
        let visualization = app.descendants(matching: .any)
            .matching(identifier: "gomoku.eclipse.visualization.quick-toggle").firstMatch
        XCTAssertTrue(visualization.waitForExistence(timeout: 6))
        let instruments = app.descendants(matching: .any)
            .matching(identifier: "gomoku.eclipse.measured-instruments.toggle").firstMatch
        scrollUntilHittable(instruments, in: app)
        instruments.tap()
        XCTAssertTrue(instruments.exists)
        instruments.tap()
        XCTAssertTrue(instruments.exists)
        // Analysis remains accessible even when the measured instruments fold.
        let analysis = app.buttons["gomoku.eclipse.visualization.open-analysis"]
        scrollUntilHittable(analysis, in: app, swipeUp: false)
        XCTAssertTrue(analysis.exists)
    }

    func testVeilLinkThinkingStrengthSliderAndNoTimeLimitAreReachable() {
        let app = XCUIApplication()
        app.launch()
        let intensity = app.descendants(matching: .any)
            .matching(identifier: "gomoku.eclipse.thinking-intensity.slider").firstMatch
        scrollUntilHittable(intensity, in: app)
        XCTAssertTrue(intensity.exists)
        let unlimited = app.descendants(matching: .any)
            .matching(identifier: "gomoku.eclipse.thinking-intensity.no-time-cutoff").firstMatch
        XCTAssertTrue(unlimited.exists)
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

        // SwiftUI does not guarantee a noninteractive VStack is a hittable
        // accessibility node. Verify its actual visible title instead.
        let learningTitle = app.staticTexts["本地自学习棋手"]
        scrollUntilHittable(learningTitle, in: app)
        capture(app, named: "Gomoku-instrument-training-expanded")
        scrollUntilHittable(advanced, in: app, swipeUp: false)
        advanced.tap()
        XCTAssertFalse(learningTitle.exists)
    }

    func testVersionedModelSelectorActuallyChangesActiveEclipseModel() {
        let app = XCUIApplication()
        app.launch()
        let picker = app.buttons["gomoku.eclipse.model.open"]
        XCTAssertTrue(picker.waitForExistence(timeout: 15))
        picker.tap()

        let luna = app.buttons["gomoku.eclipse.model.eclipse-1.0-luna"]
        let terra = app.buttons["gomoku.eclipse.model.eclipse-1.0-terra"]
        let astra = app.buttons["gomoku.eclipse.model.eclipse-1.0-astra"]
        XCTAssertTrue(astra.waitForExistence(timeout: 8))
        XCTAssertTrue(luna.exists)
        capture(app, named: "Gomoku-ECLIPSE-R15-model-library")

        // Switch to a known different version first so this tests actual
        // state transitions even if the simulator persisted Astra previously.
        terra.tap()
        XCTAssertTrue(app.staticTexts[
            "你 vs ECLIPSE 1.0 Terra · 离线对局"
        ].waitForExistence(timeout: 8))
        picker.tap()
        XCTAssertTrue(astra.waitForExistence(timeout: 8))
        astra.tap()
        XCTAssertTrue(app.staticTexts[
            "你 vs ECLIPSE 1.0 Astra · 离线对局"
        ].waitForExistence(timeout: 8))

        // Original seven search budget mappings and compute-tier changes are
        // independently asserted in EclipseModelCatalogTests; do not make
        // this UI smoke test depend on LazyVStack offscreen menu virtualization.
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
        let scrollable = app.scrollViews.firstMatch
        for _ in 0..<15 {
            if element.isHittable { return }
            // Swipe the native ScrollView, not the board or app surface.
            // The board has tap and visualization gesture layers.
            if scrollable.exists {
                if swipeUp { scrollable.swipeUp() }
                else { scrollable.swipeDown() }
            } else {
                if swipeUp { app.swipeUp() }
                else { app.swipeDown() }
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
