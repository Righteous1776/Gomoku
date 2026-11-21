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
        let terraLabel = app.staticTexts["你 vs ECLIPSE 1.0 Terra · 离线对局"]
        scrollUntilHittable(terraLabel, in: app)
        XCTAssertTrue(terraLabel.exists)
        picker.tap()
        XCTAssertTrue(astra.waitForExistence(timeout: 8))
        astra.tap()
        let astraLabel = app.staticTexts["你 vs ECLIPSE 1.0 Astra · 离线对局"]
        scrollUntilHittable(astraLabel, in: app)
        XCTAssertTrue(astraLabel.exists)

        // Original seven search budget mappings and compute-tier changes are
        // independently asserted in EclipseModelCatalogTests; do not make
        // this UI smoke test depend on LazyVStack offscreen menu virtualization.
    }

    func testLiveThinkingRibbonIsInteractiveWithoutCoveringBoard() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["game.eclipse.identity"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.descendants(matching: .any)[
            "gomoku.instrument.board"
        ].exists)
        let ribbon = app.descendants(matching: .any)[
            "gomoku.eclipse.live-telemetry"
        ]
        let switcher = app.buttons["gomoku.eclipse.live-visibility"]
        // A non-interactive ribbon is intentionally not a hittable target.
        // Scroll to its genuine button instead.
        scrollUntilHittable(switcher, in: app)
        XCTAssertTrue(ribbon.exists)
        XCTAssertTrue(switcher.isHittable)
        switcher.tap()
        // The eye button must really change the persisted visibility state.
        let offLabel = "关闭棋盘思考可视化"
        let onLabel = "开启棋盘思考可视化"
        let actualLabel = switcher.label
        XCTAssertTrue(actualLabel == offLabel || actualLabel == onLabel)
        switcher.tap()
        let detail = app.buttons["gomoku.eclipse.analysis.open"]
        scrollUntilHittable(detail, in: app)
        detail.tap()
        XCTAssertTrue(app.navigationBars["ECLIPSE // TRACE"]
            .waitForExistence(timeout: 6))
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
