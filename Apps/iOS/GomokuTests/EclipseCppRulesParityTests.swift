import XCTest
@testable import Gomoku

/// Phase 1: C++/Swift move legality and state parity. NOT search-strength
/// parity and never authorization to activate the C++ prototype in gameplay.
final class EclipseCppRulesParityTests: XCTestCase {
    private func assertMatchesSwift(_ history: [Int],
                                    file: StaticString = #filePath,
                                    line: UInt = #line) {
        var swift = GomokuState()
        for square in history {
            XCTAssertTrue(swift.apply(index: square, actor: swift.currentPlayer),
                          file: file, line: line)
        }
        guard let foreign = EclipseCppRulesParityProbe.replay(history) else {
            XCTFail("C ABI rejected a valid Swift match", file: file, line: line)
            return
        }
        XCTAssertEqual(foreign.board,
                       (0..<225).map { UInt8(swift.value(at: $0)) },
                       file: file, line: line)
        XCTAssertEqual(foreign.toMove, swift.currentPlayer == .host ? 1 : 2,
                       file: file, line: line)
        XCTAssertEqual(foreign.status,
                       swift.winner == .host ? 1
                       : swift.winner == .guest ? 2 : swift.isDraw ? 3 : 0,
                       file: file, line: line)
    }

    func testABIAndTerminalTurnPreservation() {
        XCTAssertEqual(eg_rules_abi_version(), 1)
        [
            [],
            [112],
            [112, 113],
            [0, 15, 1, 16, 2, 17, 3, 18, 4],
            [15, 0, 30, 1, 45, 2, 60, 3, 100, 4],
            [0, 1, 16, 2, 32, 3, 48, 4, 64]
        ].forEach(assertMatchesSwift)
    }

    func testMalformedSequencesNeverCrossAsValid() {
        XCTAssertNil(EclipseCppRulesParityProbe.replay([225]))
        XCTAssertNil(EclipseCppRulesParityProbe.replay([-1]))
        XCTAssertNil(EclipseCppRulesParityProbe.replay([112, 112]))
        XCTAssertNil(EclipseCppRulesParityProbe.replay(
            [0, 15, 1, 16, 2, 17, 3, 18, 4, 20]
        ))
    }

    func testNonTerminalDeterministicMultiPlyParity() {
        var histories: [[Int]] = []
        var history: [Int] = []
        // Widely spaced, no five-in-a-row until deliberately completed.
        for square in [112, 40, 84, 163, 142, 19, 93, 205, 121, 17] {
            history.append(square)
            histories.append(history)
        }
        histories.forEach(assertMatchesSwift)
    }
}
