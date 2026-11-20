import Foundation
import XCTest
@testable import Gomoku

final class GomokuCoachProfileTests: XCTestCase {
    func testCoachDerivesCountsFromRealVerifiedPersistentHistoryOnly() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("GomokuCoach-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let archive = VeilGomokuMatchArchive(directory: folder.appendingPathComponent("matches"))
        let moves: [VeilGomokuMatchArchive.Move] = (0..<9).map { index in
            .init(index: index.isMultiple(of: 2) ? 105 + index / 2 : index / 2,
                  stone: index.isMultiple(of: 2) ? 1 : 2)
        }
        let completed = try XCTUnwrap(archive.save(
            sessionID: UUID().uuidString, moves: moves,
            difficulty: "balanced", humanStone: 1, status: .humanWon
        ))
        let evidence = GomokuLocalMatchEvidence(
            directory: folder.appendingPathComponent("proofs"),
            testingKey: Data(repeating: 0x41, count: 32)
        )
        try evidence.attestCommittedLocalMatch(completed)
        _ = try archive.save(
            sessionID: UUID().uuidString, moves: Array(moves.prefix(2)),
            difficulty: "balanced", humanStone: 1, status: .playing
        )
        let training = folder.appendingPathComponent("training")
        let profile = GomokuCoachProfile.build(
            archiveDirectory: archive.directory, trainingDirectory: training,
            developerFormationCount: 0, localEvidence: evidence
        )
        XCTAssertEqual(profile.completedHumanGames, 1)
        XCTAssertEqual(profile.verifiedSelfPlayGames, 0)
        XCTAssertEqual(profile.verifiedLegacyGames, 0)
        XCTAssertEqual(profile.repeatedLosingLines, 0)
        XCTAssertEqual(profile.developerFormations, 0)
        XCTAssertGreaterThan(profile.rememberedPositions, 0)
        XCTAssertGreaterThanOrEqual(profile.level, 1)
        XCTAssertTrue(profile.favoriteOpening.contains("边侧"))
    }
}
