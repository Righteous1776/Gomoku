import Foundation
import XCTest
@testable import Gomoku

@MainActor
final class GomokuRecoveryTests: XCTestCase {
    func testAppRelaunchOffersExactValidUnfinishedMatch() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("GomokuRecover-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let archiveDirectory = folder.appendingPathComponent("history")
        let archive = VeilGomokuMatchArchive(directory: archiveDirectory)
        let id = UUID().uuidString
        let started = Date(timeIntervalSince1970: 1_700_000_000)
        let moves = [
            VeilGomokuMatchArchive.Move(index: 105, stone: 1),
            VeilGomokuMatchArchive.Move(index: 0, stone: 2)
        ]
        _ = try archive.save(sessionID: id, moves: moves,
                             difficulty: "zenith", humanStone: 1,
                             status: .playing, now: started)
        let relaunched = NativeGomokuAppController(
            archiveDirectory: archiveDirectory,
            trainingDirectory: folder.appendingPathComponent("training")
        )
        XCTAssertTrue(relaunched.recoveryAvailable)
        XCTAssertTrue(relaunched.restoreLastPlayingSession())
        XCTAssertEqual(relaunched.sessionID, id)
        XCTAssertEqual(relaunched.state.moveCount, 2)
        XCTAssertEqual(relaunched.board[105], 1)
        XCTAssertEqual(relaunched.board[0], 2)
        XCTAssertEqual(relaunched.difficulty, .zenith)
        XCTAssertEqual(relaunched.status, 0)
        XCTAssertFalse(relaunched.isThinking)
        XCTAssertEqual(try archive.read(sessionID: id)?.startedAt, started)
        XCTAssertEqual(try archive.read(sessionID: id)?.status, .playing)
    }

    func testLargeHistoryRecoveryUsesLatestPlayingAndPreservesFinals() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("GomokuRecoverLarge-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let journal = VeilGomokuMatchArchive(
            directory: folder.appendingPathComponent("history")
        )
        let early = Date(timeIntervalSince1970: 1_700_000_000)
        let first = UUID().uuidString
        let second = UUID().uuidString
        let moves = [
            VeilGomokuMatchArchive.Move(index: 112, stone: 1),
            VeilGomokuMatchArchive.Move(index: 113, stone: 2)
        ]
        _ = try journal.save(sessionID: first, moves: moves,
                             difficulty: "balanced", humanStone: 1,
                             status: .playing, now: early)
        // Many completed games may sit between two interrupted sessions.
        for i in 0..<120 {
            let id = UUID().uuidString
            let terminal = (0..<9).map { turn in
                VeilGomokuMatchArchive.Move(
                    index: turn.isMultiple(of: 2) ? 105 + turn / 2 : turn / 2,
                    stone: turn.isMultiple(of: 2) ? 1 : 2
                )
            }
            _ = try journal.save(sessionID: id, moves: terminal,
                                 difficulty: "balanced", humanStone: 1,
                                 status: .humanWon,
                                 now: early.addingTimeInterval(Double(i + 1) * 60))
        }
        _ = try journal.save(sessionID: second, moves: moves,
                             difficulty: "zenith", humanStone: 2,
                             status: .playing, now: early.addingTimeInterval(10_000))
        XCTAssertEqual(try journal.recordCount(), 122)
        XCTAssertEqual(Array(journal.verifiedMatches()).count, 122)
        XCTAssertEqual(
            try journal.mostRecentMatch { $0.status == .playing }?.id,
            second
        )
        let controller = NativeGomokuAppController(
            archiveDirectory: journal.directory,
            trainingDirectory: folder.appendingPathComponent("training")
        )
        XCTAssertTrue(controller.recoveryAvailable)
        XCTAssertTrue(controller.restoreLastPlayingSession())
        XCTAssertEqual(controller.sessionID, second)
        XCTAssertEqual(controller.archivedGames, 122)
        XCTAssertEqual(controller.humanColor, 2)
    }

    func testFinalOrBrokenGameDoesNotSilentlyResume() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("GomokuRecoverReject-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let archive = VeilGomokuMatchArchive(directory: folder.appendingPathComponent("history"))
        let id = UUID().uuidString
        let moves: [VeilGomokuMatchArchive.Move] = (0..<9).map { index in
            .init(index: index.isMultiple(of: 2) ? 105 + index / 2 : index / 2,
                  stone: index.isMultiple(of: 2) ? 1 : 2)
        }
        _ = try archive.save(sessionID: id, moves: moves,
                             difficulty: "balanced", humanStone: 1,
                             status: .humanWon)
        let relaunched = NativeGomokuAppController(
            archiveDirectory: archive.directory,
            trainingDirectory: folder.appendingPathComponent("training")
        )
        XCTAssertFalse(relaunched.recoveryAvailable)
        XCTAssertFalse(relaunched.restoreLastPlayingSession())
        XCTAssertEqual(relaunched.state.moveCount, 0)
        XCTAssertEqual(try archive.read(sessionID: id)?.status, .humanWon)
    }
}
