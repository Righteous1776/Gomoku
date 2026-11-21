import XCTest
@testable import Gomoku

/// Research-engine smoke tests, not a game-strength parity certificate.
final class NativeEclipseResearchTests: XCTestCase {
    func testRejectsMalformedBoard() {
        XCTAssertNil(NativeEclipseResearch.decide(cells: [], toMove: 1))
        XCTAssertNil(NativeEclipseResearch.decide(
            cells: Array(repeating: 0, count: 225), toMove: 3
        ))
    }

    func testNativeDecisionIsLegalOnEmptyBoard() {
        let board = [UInt8](repeating: 0, count: 225)
        let decision = NativeEclipseResearch.decide(
            cells: board, toMove: 1, difficulty: "relaxed",
            maximumMilliseconds: 150
        )
        XCTAssertNotNil(decision)
        if let move = decision?.index {
            XCTAssertTrue((0..<225).contains(move))
            XCTAssertEqual(board[move], 0)
        }
    }

    func testR12FindsImmediateFive() {
        var cells = [UInt8](repeating: 0, count: 225)
        for col in 5...8 { cells[7 * 15 + col] = 1 }
        let probe = EclipseHorizonQuiescenceR12.inspect(
            cells, toMove: 1
        )
        switch probe {
        case .ownImmediateWin(let index):
            XCTAssertTrue([7 * 15 + 4, 7 * 15 + 9].contains(index))
        default:
            XCTFail("A four-in-a-row with two available ends must give an immediate win.")
        }
    }
}
