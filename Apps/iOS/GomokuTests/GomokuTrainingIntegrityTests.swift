import Foundation
import XCTest
@testable import Gomoku

final class GomokuTrainingIntegrityTests: XCTestCase {
    private func tempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("GomokuTrainingIntegrity-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func completedGame(outcome: AdaptiveBoardGameResult) -> NativeGomokuSelfPlayGame {
        // Legal, terminal 9-ply example: black wins horizontally.
        var state = GomokuState()
        var plies: [AdaptiveBoardPly] = []
        for index in [105, 0, 106, 1, 107, 2, 108, 3, 109] {
            let actor = state.currentPlayer
            plies.append(.init(
                position: AdaptiveBoardPosition.gomoku(state),
                action: String(index), actor: actor
            ))
            XCTAssertTrue(state.apply(index: index, actor: actor))
        }
        XCTAssertEqual(state.winner, .host)
        return NativeGomokuSelfPlayGame(
            plies: plies, result: outcome, opening: 105, botDecisions: 8
        )
    }

    func testWrongWinnerLabelIsRejectedWithoutWriting() throws {
        let folder = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let journal = GomokuNativeTrainingJournal(directory: folder)
        XCTAssertThrowsError(try journal.append(completedGame(outcome: .aiWon), seed: 1))
        XCTAssertEqual(journal.count(), 0)
        XCTAssertEqual(journal.inspect().invalid, 0)
    }

    func testIdenticalSequenceCannotInflateValidGames() throws {
        let folder = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let journal = GomokuNativeTrainingJournal(directory: folder)
        let game = completedGame(outcome: .humanWon)
        _ = try journal.append(game, seed: 1)
        XCTAssertThrowsError(try journal.append(game, seed: 2))
        let restarted = GomokuNativeTrainingJournal(directory: folder)
        XCTAssertEqual(restarted.count(), 1)
        XCTAssertEqual(restarted.inspect().duplicates, 0)
    }

    func testCorruptedUUIDFileNeverInflatesValidatedCount() throws {
        let folder = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let journal = GomokuNativeTrainingJournal(directory: folder)
        _ = try journal.append(completedGame(outcome: .humanWon), seed: 3)
        let corrupt = folder.appendingPathComponent(UUID().uuidString + ".json")
        try Data("{wrong".utf8).write(to: corrupt, options: .atomic)
        XCTAssertEqual(journal.inspect().accepted, 1)
        XCTAssertEqual(journal.inspect().invalid, 1)
        XCTAssertEqual(journal.count(), 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: corrupt.path))
    }
    func testVerifiedSelfPlayExportContainsOriginalMoveEvidence() throws {
        let folder = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let journal = GomokuNativeTrainingJournal(directory: folder)
        _ = try journal.append(completedGame(outcome: .humanWon), seed: 23)

        let exported = try journal.exportVerifiedDetails()
        defer { try? FileManager.default.removeItem(at: exported) }
        let bytes = try Data(contentsOf: exported)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        XCTAssertEqual(json["schema"] as? String, "gomoku.native.selfplay-details.v1")
        XCTAssertEqual(json["verifiedGames"] as? Int, 1)
        let records = try XCTUnwrap(json["games"] as? [[String: Any]])
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0]["moves"] as? [Int], [105, 0, 106, 1, 107, 2, 108, 3, 109])
        XCTAssertEqual(records[0]["seed"] as? Int, 23)
        XCTAssertEqual(journal.count(), 1, "Export must not change stored training")
    }

    func testExportRefusesCorruptedNativeTrainingArchive() throws {
        let folder = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let journal = GomokuNativeTrainingJournal(directory: folder)
        _ = try journal.append(completedGame(outcome: .humanWon), seed: 1)
        let corrupt = folder.appendingPathComponent(UUID().uuidString + ".json")
        try Data("{wrong".utf8).write(to: corrupt, options: .atomic)

        XCTAssertThrowsError(try journal.exportVerifiedDetails())
        XCTAssertTrue(FileManager.default.fileExists(atPath: corrupt.path),
                      "Invalid original files must never be deleted or silently exported")
    }

}
