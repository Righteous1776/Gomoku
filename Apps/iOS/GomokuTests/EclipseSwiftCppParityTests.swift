import XCTest
@testable import Gomoku

/// Cross-language evidence on the SAME simulator. The Swift reference below
/// is the native UnifiedSearch; full GomokuBot + personal learning parity
/// requires a separate test suite and is NOT established here.
final class EclipseSwiftCppParityTests: XCTestCase {
    private struct Tactic {
        let name: String
        let history: [Int]
        let allowed: Set<Int>
    }

    private func replay(_ history: [Int]) -> GomokuState? {
        var board = GomokuState()
        for move in history {
            guard board.apply(index: move, actor: board.currentPlayer) else { return nil }
        }
        guard board.winner == nil, !board.isDraw else { return nil }
        return board
    }

    private func swiftMove(_ state: GomokuState, ms: Int) -> Int? {
        let cells = (0..<225).map { UInt8(max(0, state.value(at: $0))) }
        let side: UInt8 = state.currentPlayer == .host ? 1 : 2
        guard let position = VeilGomokuUnifiedSearch.Position(
            cells: cells, toMove: side
        ) else { return nil }
        var limits = VeilGomokuUnifiedSearch.Limits()
        limits.maxMilliseconds = ms
        limits.maxNodes = max(10_000, ms * 125)
        limits.maxDepth = 5
        limits.width = 18
        limits.candidateRadius = 2
        limits.forcedLineDepth = 5
        return VeilGomokuUnifiedSearch.decide(
            position, limits: limits, trainedPolicy: true
        )?.index
    }

    func testForcedTacticalObligationsOnActualSwiftAndCpp() {
        let cases: [Tactic] = [
            Tactic(name: "black immediate-five wins before opponent",
                   history: [0, 15, 1, 16, 2, 17, 3, 18], allowed: [4]),
            Tactic(name: "black compulsory block",
                   history: [112, 0, 140, 1, 200, 2, 204, 3], allowed: [4]),
            Tactic(name: "white compulsory block",
                   history: [0, 112, 1, 140, 2, 200, 3], allowed: [4]),
            Tactic(name: "black two-distinct-completion attack",
                   history: [110, 0, 111, 15, 113, 30], allowed: [112]),
            Tactic(name: "white two-distinct-completion attack",
                   history: [0, 110, 17, 111, 34, 113, 51], allowed: [112]),
            Tactic(name: "black must interrupt white next-ply fork",
                   history: [0, 110, 17, 111, 34, 113],
                   allowed: [109, 112, 114])
        ]
        for item in cases {
            guard let state = replay(item.history) else {
                XCTFail("Invalid synthetic Swift fixture: \(item.name)")
                continue
            }
            let swift = swiftMove(state, ms: 300)
            let cpp = EclipseCppResearchFixture.bestMove(
                history: item.history, milliseconds: 300
            )
            XCTAssertNotNil(swift, "Swift reference returned no move: \(item.name)")
            XCTAssertNotNil(cpp, "C++ port returned no move: \(item.name)")
            if let swift {
                XCTAssertTrue(item.allowed.contains(swift),
                              "Swift tactical reference disagrees with fixture: \(item.name), \(swift)")
            }
            if let cpp {
                XCTAssertTrue(item.allowed.contains(cpp),
                              "C++ violates Swift-compatible tactical obligation: \(item.name), \(cpp)")
            }
            print("ECLIPSE_TACTICAL_PARITY case=\(item.name) swift=\(swift ?? -1) cpp=\(cpp ?? -1)")
        }
    }

    private func pairedGame(swiftBlack: Bool, ms: Int) -> String {
        var state = GomokuState()
        var moves = [112] // same public center opening in both color-swapped games
        XCTAssertTrue(state.apply(index: 112, actor: .host))
        while state.winner == nil && !state.isDraw && moves.count < 225 {
            let useSwift = (state.currentPlayer == .host) == swiftBlack
            let move = useSwift ? swiftMove(state, ms: ms)
                : EclipseCppResearchFixture.bestMove(history: moves, milliseconds: ms)
            guard let index = move, state.apply(index: index, actor: state.currentPlayer) else {
                XCTFail("Engine returned an illegal move at ply \(moves.count), Swift=\(useSwift)")
                return "invalid"
            }
            moves.append(index)
        }
        XCTAssertTrue(state.winner != nil || state.isDraw,
                      "Paired arena must reach a legal terminal state")
        guard let winner = state.winner else { return "draw" }
        let swiftWon = (winner == .host) == swiftBlack
        return swiftWon ? "Swift" : "Cpp"
    }

    func testTwoColorSwappedGamesAreLegalAndCompleted() {
        // A TWO-GAME SMOKE TEST, NOT statistical equivalence or rank evidence.
        let first = pairedGame(swiftBlack: true, ms: 60)
        let second = pairedGame(swiftBlack: false, ms: 60)
        print("ECLIPSE_ARENA_SMOKE paired_games=2 swift_black_result=\(first) cpp_black_result=\(second)")
        XCTAssertNotEqual(first, "invalid")
        XCTAssertNotEqual(second, "invalid")
    }
}
