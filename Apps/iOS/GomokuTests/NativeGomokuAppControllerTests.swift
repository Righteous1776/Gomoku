import XCTest
@testable import Gomoku

@MainActor
final class NativeGomokuAppControllerTests: XCTestCase {
    func testStartsWithOriginalSwiftModelAnd15x15Board() {
        // An isolated app-support root must not inherit a real user's
        // persisted model selection from a previous UITest launch.
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("EclipseDefault-(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let app = NativeGomokuAppController(
            archiveDirectory: root.appendingPathComponent("history"),
            trainingDirectory: root.appendingPathComponent("training"))
        XCTAssertEqual(app.board.count, 225)
        XCTAssertEqual(app.status, 0)
        XCTAssertEqual(app.toMove, 1)
        XCTAssertEqual(app.difficulty, .balanced)
    }

    func testHumanMoveMutatesNativeBoard() {
        let app = NativeGomokuAppController()
        app.play(112)
        XCTAssertEqual(app.board[112], 1)
        XCTAssertTrue(app.isThinking || app.status != 0)
        app.reset()
        XCTAssertTrue(app.board.allSatisfy { $0 == 0 })
    }

    func testAllSevenDifficultiesPresent() {
        let app = NativeGomokuAppController()
        for tier in BoardBotDifficulty.allCases { app.difficulty = tier }
        XCTAssertEqual(app.difficulty, .zenith)
    }
}
