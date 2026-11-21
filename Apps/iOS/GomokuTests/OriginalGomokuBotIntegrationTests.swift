import XCTest
@testable import Gomoku

/// Original rules and mandatory tactical win/block gates, not full ELO evidence.
final class OriginalGomokuBotIntegrationTests: XCTestCase {
    func testSevenTiersAndSearchMultipliers() {
        XCTAssertEqual(BoardBotDifficulty.allCases.count, 7)
        XCTAssertEqual(BoardBotDifficulty.grandmaster.searchBudgetMultiplier, 2)
        XCTAssertEqual(BoardBotDifficulty.legendary.searchBudgetMultiplier, 4)
        XCTAssertEqual(BoardBotDifficulty.zenith.searchBudgetMultiplier, 6)
    }

    func testDeterministicOpeningUsesCenter() {
        let move = OriginalGomokuBotAdapter.choose(moveHistory: [])
        XCTAssertEqual(move?.index, 112)
    }

    func testMandatoryBlockAgainstBoundaryFour() {
        let history = [
            0, 7*15+0,
            2, 7*15+1,
            4, 7*15+2,
            6, 7*15+3
        ]
        let move = OriginalGomokuBotAdapter.choose(moveHistory: history)
        XCTAssertEqual(move?.index, 7*15+4)
    }

    func testRejectsInvalidMoveHistory() {
        XCTAssertNil(OriginalGomokuBotAdapter.choose(moveHistory: [112, 112]))
        XCTAssertNil(OriginalGomokuBotAdapter.choose(moveHistory: [225]))
    }
}
