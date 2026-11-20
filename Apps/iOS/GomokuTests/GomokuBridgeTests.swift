import XCTest
@testable import Gomoku

@MainActor
final class GomokuBridgeTests: XCTestCase {
    func testStartupAndFirstMove() {
        let bridge = EngineBridge()
        XCTAssertEqual(bridge.board.count, 225)
        XCTAssertEqual(bridge.toMove, 1)
        XCTAssertEqual(bridge.status, 0)
        bridge.play(112)
        XCTAssertEqual(bridge.board[112], 1)
    }
    func testReset() {
        let bridge = EngineBridge()
        bridge.play(112)
        bridge.reset()
        XCTAssertTrue(bridge.board.allSatisfy { $0 == 0 })
    }
}
