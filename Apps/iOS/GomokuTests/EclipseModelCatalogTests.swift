import Foundation
import XCTest
@testable import Gomoku

@MainActor
final class EclipseModelCatalogTests: XCTestCase {

    func testVersionedModelIDsUniqueStableAndMappedToOriginalSevenTiers() {
        XCTAssertEqual(EclipseModelID.featured.count, 7)
        XCTAssertEqual(Set(EclipseModelID.featured.map(\.rawValue)).count, 7)
        XCTAssertEqual(EclipseModelID.featured.first, .astra12)
        XCTAssertEqual(EclipseModelID.featured.last, .luna10)
        XCTAssertEqual(EclipseModelID.currentDefault, .terra10)
        for tier in BoardBotDifficulty.allCases {
            let selected = EclipseModelID.fromLegacyDifficulty(tier)
            XCTAssertEqual(selected.legacyDifficulty, tier)
            XCTAssertEqual(EclipseModelID.fromArchiveValue(tier.rawValue), selected)
            XCTAssertEqual(EclipseModelID.fromArchiveValue(selected.rawValue), selected)
            XCTAssertEqual(EclipseModelID.fromStoredIdentifier(selected.rawValue), selected)
            XCTAssertFalse(selected.artifactKind.isEmpty)
        }
        XCTAssertNil(EclipseModelID.fromArchiveValue("eclipse-999-unauthorized"))
        XCTAssertNil(EclipseModelID.fromStoredIdentifier("1.2 Astra"))
    }

    func testRealBackendPathsAndIncreasingOriginalComputePolicies() {
        XCTAssertEqual(EclipseModelID.luna10.backend, .classicSwift)
        XCTAssertFalse(EclipseModelID.luna10.usesTrainedUnifiedSearch)
        for model in EclipseModelID.featured where model != .luna10 {
            XCTAssertEqual(model.backend, .trainedUnifiedSwift)
            XCTAssertTrue(model.usesTrainedUnifiedSearch)
        }
        let budgets = EclipseModelID.featured.reversed().map {
            $0.fullComputeBudgetMilliseconds
        }
        XCTAssertEqual(budgets, [130, 260, 520, 950, 1900, 3800, 5700])
        XCTAssertEqual(EclipseModelID.astra12.legacyDifficulty, .zenith)
        XCTAssertEqual(EclipseModelID.sol11.legacyDifficulty, .master)
    }

    func testControllerChangingModelActuallyChangesStrategyAndResetsGame() throws {
        let old = UserDefaults.standard.string(forKey: EclipseModelID.selectionKey)
        defer {
            if let old {
                UserDefaults.standard.set(old, forKey: EclipseModelID.selectionKey)
            } else {
                UserDefaults.standard.removeObject(forKey: EclipseModelID.selectionKey)
            }
        }
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EclipseModelR14-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let game = NativeGomokuAppController(
            archiveDirectory: dir.appendingPathComponent("history"),
            trainingDirectory: dir.appendingPathComponent("training"))
        XCTAssertEqual(game.selectedModel, .terra10)
        game.play(112)
        XCTAssertEqual(game.board[112], 1)
        game.selectModel(.astra12)
        XCTAssertEqual(game.selectedModel, .astra12)
        XCTAssertEqual(game.difficulty, .zenith)
        XCTAssertTrue(game.board.allSatisfy { $0 == 0 })
        XCTAssertEqual(UserDefaults.standard.string(
            forKey: EclipseModelID.selectionKey), EclipseModelID.astra12.rawValue)
        game.selectModel(.luna10)
        XCTAssertFalse(game.selectedModel.usesTrainedUnifiedSearch)
        XCTAssertEqual(game.difficulty, .relaxed)
        XCTAssertNotEqual(EclipseModelID.luna10.artifactKind,
                          EclipseModelID.astra12.artifactKind)
    }

    func testModelIDArchivedAndLegacyGamesRemainRecoverableUnmodified() throws {
        let old = UserDefaults.standard.string(forKey: EclipseModelID.selectionKey)
        defer {
            if let old {
                UserDefaults.standard.set(old, forKey: EclipseModelID.selectionKey)
            } else {
                UserDefaults.standard.removeObject(forKey: EclipseModelID.selectionKey)
            }
        }
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EclipseModelArchive-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let archive = VeilGomokuMatchArchive(directory:
            dir.appendingPathComponent("history"))
        let gameID = UUID().uuidString
        let opening = [
            VeilGomokuMatchArchive.Move(index: 112, stone: 1),
            VeilGomokuMatchArchive.Move(index: 97, stone: 2)
        ]
        _ = try archive.save(sessionID: gameID, moves: opening,
                             difficulty: EclipseModelID.astra12.rawValue,
                             humanStone: 1, status: .playing)
        let resume = NativeGomokuAppController(
            archiveDirectory: archive.directory,
            trainingDirectory: dir.appendingPathComponent("training"))
        XCTAssertTrue(resume.recoveryAvailable)
        XCTAssertTrue(resume.restoreLastPlayingSession())
        XCTAssertEqual(resume.selectedModel, .astra12)
        XCTAssertEqual(resume.difficulty, .zenith)
        XCTAssertEqual(try archive.read(sessionID: gameID)?.difficulty,
                       EclipseModelID.astra12.rawValue)
    }
}
