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

    func testMidnightBoardAndAdvancedPanel() {
        let app = XCUIApplication()
        app.launchArguments += ["-appearance.color.mode.v1", "dark"]
        app.launch()

        let advanced = app.buttons["gomoku.advanced.open"]
        XCTAssertTrue(advanced.waitForExistence(timeout: 15))
        capture(app, named: "Gomoku-midnight-board")
        advanced.tap()
        let panel = app.navigationBars["高级面板"]
        XCTAssertTrue(panel.waitForExistence(timeout: 6))
        let midnight = app.buttons["深夜"]
        XCTAssertTrue(midnight.exists)
        XCTAssertTrue(midnight.isSelected)
        XCTAssertTrue(app.switches["gomoku.eclipse.live-trace.toggle"].exists)
        capture(app, named: "Gomoku-midnight-advanced")
        panel.buttons["完成"].tap()
        XCTAssertTrue(advanced.waitForExistence(timeout: 6))
    }

    private func capture(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
