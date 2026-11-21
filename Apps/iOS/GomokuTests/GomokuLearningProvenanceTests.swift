import CryptoKit
import Foundation
import XCTest
@testable import Gomoku

final class GomokuLearningProvenanceTests: XCTestCase {
    private func moves() -> [VeilGomokuMatchArchive.Move] {
        let indices = [105, 0, 106, 1, 107, 2, 108, 3, 109]
        return indices.enumerated().map { offset, index in
            VeilGomokuMatchArchive.Move(index: index, stone: offset.isMultiple(of: 2) ? 1 : 2)
        }
    }

    func testReferenceJSONImportCannotChangeLearningWithoutLocalProof() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("GomokuEvidence-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: base) }
        let source = VeilGomokuMatchArchive(directory: base.appendingPathComponent("source"))
        let targetDirectory = base.appendingPathComponent("Gomoku/History")
        let target = VeilGomokuMatchArchive(directory: targetDirectory)
        let id = UUID().uuidString
        let original = try XCTUnwrap(source.save(
            sessionID: id, moves: moves(), difficulty: "balanced",
            humanStone: 1, status: .humanWon
        ))
        XCTAssertTrue(original.isReplayable)
        let url = try GomokuMatchTransfer(archive: source).exportMostRecent()
        defer { try? FileManager.default.removeItem(at: url) }
        _ = try GomokuMatchTransfer(archive: target).importMatch(from: url)

        let key = Data(repeating: 0x4D, count: 32)
        let evidence = GomokuLocalMatchEvidence(
            directory: base.appendingPathComponent("Gomoku/VerifiedLocalLearningV1"),
            testingKey: key
        )
        let imported = try XCTUnwrap(target.read(sessionID: id))
        XCTAssertFalse(evidence.isVerifiedLocal(imported),
                       "An imported JSON record must not create a local attestation")

        func snapshot() -> GomokuLearningRepertoire.BuildReport {
            GomokuLearningRepertoire.build(
                journalDirectory: base.appendingPathComponent("Gomoku/NativeSelfPlayV1"),
                archiveDirectory: targetDirectory,
                currentMoves: [], humanStone: 1,
                includeNativeSelfPlay: false,
                importedLegacyDirectory: base.appendingPathComponent("Gomoku/empty-legacy"),
                localEvidence: evidence
            )
        }
        let untrusted = snapshot()
        XCTAssertEqual(untrusted.validHumanGames, 0)
        XCTAssertEqual(untrusted.snapshot.trainingLevel, 0)

        // The live controller, not the import route, is the only caller of
        // attestCommittedLocalMatch. This models that local commit boundary.
        try evidence.attestCommittedLocalMatch(imported)
        XCTAssertTrue(evidence.isVerifiedLocal(imported))
        let trusted = snapshot()
        XCTAssertEqual(trusted.validHumanGames, 1)
        // Here the human (black) won. The AI's reply (white) in a lost
        // game must be penalized rather than positively reinforced.
        XCTAssertLessThan(trusted.snapshot.bonus(position: {
            var state = GomokuState()
            XCTAssertTrue(state.apply(index: 105, actor: .host))
            return AdaptiveBoardPosition.gomoku(state)
        }(), action: "0"), 0)
    }

    func testChangedMatchCannotReuseValidReceipt() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("GomokuEvidenceTamper-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: base) }
        let history = VeilGomokuMatchArchive(directory: base.appendingPathComponent("history"))
        let id = UUID().uuidString
        let saved = try XCTUnwrap(history.save(
            sessionID: id, moves: moves(), difficulty: "balanced",
            humanStone: 1, status: .humanWon
        ))
        let evidence = GomokuLocalMatchEvidence(
            directory: base.appendingPathComponent("proofs"),
            testingKey: Data(repeating: 0x31, count: 32)
        )
        try evidence.attestCommittedLocalMatch(saved)
        XCTAssertTrue(evidence.isVerifiedLocal(saved))
        // Same ID and moves but changed timestamp / payload invalidates MAC,
        // even though an attacker could edit a standalone JSON transfer.
        let tampered = VeilGomokuMatchArchive.Match(
            version: saved.version, id: saved.id, startedAt: saved.startedAt,
            updatedAt: saved.updatedAt.addingTimeInterval(1),
            completedAt: saved.completedAt?.addingTimeInterval(1),
            status: saved.status, difficulty: saved.difficulty,
            humanStone: saved.humanStone, moves: saved.moves
        )
        XCTAssertFalse(evidence.isVerifiedLocal(tampered))
    }
}
