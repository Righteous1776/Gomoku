import Foundation
import XCTest
@testable import Gomoku

final class GomokuLearningRepertoireTests: XCTestCase {
    private func game(whiteOffset: Int) -> NativeGomokuSelfPlayGame {
        var state = GomokuState()
        var plies: [AdaptiveBoardPly] = []
        let indices = [105, whiteOffset, 106, whiteOffset + 1,
                       107, whiteOffset + 2, 108, whiteOffset + 3, 109]
        for index in indices {
            let actor = state.currentPlayer
            plies.append(AdaptiveBoardPly(
                position: AdaptiveBoardPosition.gomoku(state),
                action: String(index), actor: actor
            ))
            XCTAssertTrue(state.apply(index: index, actor: actor))
        }
        XCTAssertEqual(state.winner, .host)
        return NativeGomokuSelfPlayGame(plies: plies, result: .humanWon,
                                         opening: 105, botDecisions: 8)
    }

    func testVerifiedNativeTrainingChangesActualRootBonusAfterRestart() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("GomokuRepertoire-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let training = folder.appendingPathComponent("training")
        let archive = folder.appendingPathComponent("archive")
        let journal = GomokuNativeTrainingJournal(directory: training)
        let position: String = {
            var game = GomokuState()
            XCTAssertTrue(game.apply(index: 105, actor: .host))
            return AdaptiveBoardPosition.gomoku(game)
        }()
        let without = GomokuLearningRepertoire.build(
            journalDirectory: training, archiveDirectory: archive,
            currentMoves: [], humanStone: 1
        )
        XCTAssertEqual(without.snapshot.bonus(position: position, action: "0"), 0)
        for (seed, offset) in [0, 15, 30].enumerated() {
            _ = try journal.append(game(whiteOffset: offset), seed: seed)
        }
        // Fresh builder instance, no live in-memory training state.
        let reloaded = GomokuLearningRepertoire.build(
            journalDirectory: training, archiveDirectory: archive,
            currentMoves: [], humanStone: 1
        )
        XCTAssertEqual(reloaded.validNativeGames, 3)
        XCTAssertNotEqual(reloaded.snapshot.bonus(position: position, action: "0"), 0)
        XCTAssertGreaterThan(reloaded.snapshot.trainingLevel, 0)
        let baseline = GomokuBotBudget.forDifficulty(.balanced, profileLabel: "HIGH")
        XCTAssertGreaterThan(
            baseline.reinforced(by: reloaded.snapshot.trainingLevel).rootCandidateLimit,
            baseline.rootCandidateLimit
        )
        let optedOut = GomokuLearningRepertoire.build(
            journalDirectory: training, archiveDirectory: archive,
            currentMoves: [], humanStone: 1, includeNativeSelfPlay: false
        )
        XCTAssertEqual(optedOut.snapshot.bonus(position: position, action: "0"), 0)
    }

    func testVerifiedLearningCannotOverrideMandatoryFiveBlock() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("GomokuTactics-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let journal = GomokuNativeTrainingJournal(directory: folder.appendingPathComponent("training"))
        _ = try journal.append(game(whiteOffset: 15), seed: 1)
        let learning = GomokuLearningRepertoire.build(
            journalDirectory: journal.directory,
            archiveDirectory: folder.appendingPathComponent("archive"),
            currentMoves: [], humanStone: 1
        ).snapshot
        // Black has four at 105...108; it is White's turn, which must block 109.
        let moves = [105, 0, 106, 1, 107, 2, 108]
        let decision = OriginalGomokuBotAdapter.choose(
            moveHistory: moves,
            difficulty: .balanced, profileLabel: "HIGH",
            learning: learning
        )
        XCTAssertEqual(decision?.index, 109)
    }
}
