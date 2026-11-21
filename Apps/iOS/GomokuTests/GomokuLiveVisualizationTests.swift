import XCTest
@testable import Gomoku

final class GomokuLiveVisualizationTests: XCTestCase {
    func testBranchesAreScopedToTheActiveSearchAndRevokedOnReset() throws {
        var board = GomokuState()
        XCTAssertTrue(board.apply(index: 112, actor: .host))
        let trace = VeilEclipseSearchTraceStore()
        let token = try XCTUnwrap(trace.begin(sessionID: "match", board: board))

        XCTAssertFalse(trace.record([112], nodes: 1, token: token))
        XCTAssertTrue(trace.record([113, 114], nodes: 2, token: token))
        XCTAssertEqual(trace.snapshot(sessionID: "match", turn: 1, playing: true, aiThinking: true).map(\.indices), [[113, 114]])
        XCTAssertTrue(trace.snapshot(sessionID: "old", turn: 1, playing: true, aiThinking: true).isEmpty)
        XCTAssertTrue(trace.snapshot(sessionID: "match", turn: 2, playing: true, aiThinking: true).isEmpty)
        XCTAssertTrue(trace.snapshot(sessionID: "match", turn: 1, playing: false, aiThinking: true).isEmpty)
        XCTAssertTrue(trace.snapshot(sessionID: "match", turn: 1, playing: true, aiThinking: false).isEmpty)

        trace.clear()
        XCTAssertFalse(trace.record([115], nodes: 3, token: token))
        XCTAssertTrue(trace.snapshot(sessionID: "match", turn: 1, playing: true, aiThinking: true).isEmpty)
    }
}
