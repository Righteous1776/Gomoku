import Foundation
import XCTest
@testable import Gomoku

final class GomokuTrainingWriteGateTests: XCTestCase {
    func testCancelledGenerationCannotAppendIntoRestartedSession() throws {
        let gate = GomokuTrainingWriteGate()
        let older = UUID()
        let newer = UUID()
        gate.begin(older)
        var evidence: [Int] = []
        let first = gate.commit(generation: older) {
            evidence.append(10)
            return 1
        }
        XCTAssertEqual(first, 1)
        gate.revoke()
        gate.begin(newer)
        XCTAssertNil(gate.commit(generation: older) {
            evidence.append(999)
            return 999
        })
        XCTAssertEqual(gate.commit(generation: newer) {
            evidence.append(20)
            return 2
        }, 2)
        XCTAssertEqual(evidence, [10, 20])
        gate.revoke()
        XCTAssertNil(gate.commit(generation: newer) { 3 })
    }

    private func completedGame(whiteFirst: Int) -> NativeGomokuSelfPlayGame {
        var state = GomokuState()
        var plies: [AdaptiveBoardPly] = []
        let indices = [105, whiteFirst, 106, whiteFirst + 1,
                       107, whiteFirst + 2, 108, whiteFirst + 3, 109]
        for index in indices {
            let actor = state.currentPlayer
            plies.append(.init(
                position: AdaptiveBoardPosition.gomoku(state),
                action: String(index), actor: actor
            ))
            XCTAssertTrue(state.apply(index: index, actor: actor))
        }
        return NativeGomokuSelfPlayGame(
            plies: plies, result: .humanWon,
            opening: 105, botDecisions: 8
        )
    }

    func testBatchWriterPersistsUniqueGamesAndRejectsRepeats() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("GomokuBatch-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let journal = GomokuNativeTrainingJournal(directory: folder)
        let writer = try journal.makeBatchWriter()
        XCTAssertEqual(writer.initialValidCount, 0)
        _ = try writer.append(completedGame(whiteFirst: 0), seed: 1)
        _ = try writer.append(completedGame(whiteFirst: 15), seed: 2)
        XCTAssertThrowsError(try writer.append(completedGame(whiteFirst: 0), seed: 3)) {
            XCTAssertTrue($0 is GomokuNativeTrainingJournalError)
        }
        XCTAssertEqual(writer.totalValidCount, 2)
        let restarted = try GomokuNativeTrainingJournal(directory: folder).makeBatchWriter()
        XCTAssertEqual(restarted.initialValidCount, 2)
        XCTAssertEqual(journal.count(), 2)
    }

    func testCorruptedArchiveRefusesNewBatchWithoutOverwritingEvidence() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("GomokuBatchCorrupt-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(UUID().uuidString + ".json")
        let damaged = Data("{corrupted".utf8)
        try damaged.write(to: url, options: .atomic)
        XCTAssertThrowsError(try GomokuNativeTrainingJournal(directory: folder).makeBatchWriter())
        XCTAssertEqual(try Data(contentsOf: url), damaged)
    }
}
